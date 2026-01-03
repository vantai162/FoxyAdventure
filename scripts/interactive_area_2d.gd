class_name InteractiveArea2D
extends Area2D
## Interactive Area for player-triggered interactions (chests, levers, NPCs, etc.)
## 
## CRITICAL: Only responds to Player (in "player" group), not any body.
## Each instance tracks its own interaction state independently.
##
## Uses _process() polling pattern for input (matches lever behavior).
## This bypasses event propagation chain and guarantees reliable input detection.

signal interacted  ## Emitted when player presses interact while in this area
signal interaction_available  ## Emitted when player enters interaction range
signal interaction_unavailable  ## Emitted when player leaves interaction range

@export var interact_input_action: String = "interact"

## Track whether THIS specific area has the player inside
var _player_inside: bool = false
var _current_player: Node2D = null  ## Track actual player reference for cleanup


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	get_tree().node_removed.connect(_on_any_node_removed)


func _exit_tree() -> void:
	if get_tree() and get_tree().node_removed.is_connected(_on_any_node_removed):
		get_tree().node_removed.disconnect(_on_any_node_removed)


func _on_any_node_removed(node: Node) -> void:
	if _current_player == node:
		_player_inside = false
		_current_player = null


func _process(_delta: float) -> void:
	if not _player_inside:
		return
	
	if Input.is_action_just_pressed(interact_input_action):
		interacted.emit()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	_player_inside = true
	_current_player = body
	interaction_available.emit()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	_player_inside = false
	_current_player = null
	interaction_unavailable.emit()
