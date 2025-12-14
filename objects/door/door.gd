extends Node2D
## Interactive door that teleports player to another scene or same-scene location.
## Player must interact (press button) to enter.
##
## For cross-scene: set target_stage to destination scene path
## For same-scene: set target_stage to "" and target_door to the destination door name

@export_file("*.tscn") var target_stage = ""
@export var target_door = "Door"
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _is_transitioning: bool = false


func _ready() -> void:
	sprite.play("idle")


func _on_interactive_area_2d_interacted() -> void:
	if _is_transitioning:
		return
	
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
	## Cross-scene teleport using GameManager (handles fade and scene change)
	_is_transitioning = true
	GameManager.change_stage(target_stage, target_door)
	# Note: GameManager.change_stage handles fade and scene change internally


func _teleport_same_scene() -> void:
	## Same-scene teleport: find target door and move player there
	_is_transitioning = true
	
	var player = GameManager.player
	if player == null:
		push_warning("Door: No player found for same-scene teleport")
		_is_transitioning = false
		return
	
	# Find destination door
	var destination = get_tree().current_scene.find_child(target_door, true, false)
	if destination == null:
		push_warning("Door: Could not find destination '%s'" % target_door)
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
	
	
func open_door() -> void:
	sprite.play("opening")

func close_door() -> void:
	sprite.play("closing")
	await sprite.animation_finished
	sprite.play("idle")

func _on_area_2d_body_entered(body: Node2D) -> void:
	open_door()
func _on_area_2d_body_exited(body: Node2D) -> void:
	close_door()
