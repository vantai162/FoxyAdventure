extends Node2D
## Dark cave entrance that auto-teleports player when entered.
## Uses a "touch then exit to enable" pattern to prevent immediate teleport on spawn.
##
## For cross-scene: set target_stage to destination scene path
## For same-scene: set target_stage to "" and target_door to the destination

@export_file("*.tscn") var target_stage = ""
@export var target_door = "Door"
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Only enables after player first exits the zone (prevents spawn-teleport)
@export var can_enter: bool = false

var _is_transitioning: bool = false


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player) or not can_enter or _is_transitioning:
		return
	
	_is_transitioning = true
	
	var current_scene_path = get_tree().current_scene.scene_file_path
	var target_path = target_stage
	
	# Resolve UID to path if needed
	if target_stage.begins_with("uid://"):
		target_path = ResourceUID.get_id_path(ResourceUID.text_to_id(target_stage))
	
	# Determine if cross-scene or same-scene teleport
	var is_same_scene = target_stage.is_empty() or current_scene_path == target_path
	
	if is_same_scene:
		await _teleport_same_scene()
	else:
		_teleport_cross_scene()


func _teleport_cross_scene() -> void:
	## Cross-scene teleport using GameManager
	GameManager.change_stage(target_stage, target_door)


func _teleport_same_scene() -> void:
	## Same-scene teleport: find target and move player there
	var player = GameManager.player
	if player == null:
		push_warning("DarkEntrance: No player found for same-scene teleport")
		_is_transitioning = false
		return
	
	# Find destination
	var destination = get_tree().current_scene.find_child(target_door, true, false)
	if destination == null:
		push_warning("DarkEntrance: Could not find destination '%s'" % target_door)
		_is_transitioning = false
		return
	
	# Use TransitionEffects for smooth fade
	var transition_fx = get_node_or_null("/root/TransitionEffects")
	if transition_fx:
		await transition_fx.fade_out(0.3)
	else:
		await GameManager.fade_to_black(0.3)
	
	# Teleport player
	player.global_position = destination.global_position
	player.velocity = Vector2.ZERO
	
	await get_tree().process_frame
	
	# Fade back in
	if transition_fx:
		await transition_fx.fade_in(0.3)
	else:
		await GameManager.fade_from_black(0.3)
	
	_is_transitioning = false


func _on_body_exited(body: Node2D) -> void:
	## Enable entrance after player first leaves the zone
	## This prevents immediate teleport when spawning inside the zone
	if body is Player:
		can_enter = true
