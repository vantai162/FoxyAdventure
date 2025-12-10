class_name InteractiveArea2D
extends Area2D
## Interactive Area for player-triggered interactions (chests, levers, NPCs, etc.)
## 
## CRITICAL: Only responds to Player (in "player" group), not any body.
## Each instance tracks its own interaction state independently.

signal interacted  ## Emitted when player presses interact while in this area
signal interaction_available  ## Emitted when player enters interaction range
signal interaction_unavailable  ## Emitted when player leaves interaction range

@export var interact_input_action: String = "interact"

## Track whether THIS specific area has the player inside
var _player_inside: bool = false


func _ready() -> void:
	set_process_unhandled_input(false)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	# Only process if player is actually inside THIS area
	if not _player_inside:
		return
	
	if event.is_action_pressed(interact_input_action):
		interacted.emit()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	# Only respond to bodies in the "player" group
	if not body.is_in_group("player"):
		return
	
	_player_inside = true
	set_process_unhandled_input(true)
	interaction_available.emit()


func _on_body_exited(body: Node2D) -> void:
	# Only respond to bodies in the "player" group
	if not body.is_in_group("player"):
		return
	
	_player_inside = false
	set_process_unhandled_input(false)
	interaction_unavailable.emit()
