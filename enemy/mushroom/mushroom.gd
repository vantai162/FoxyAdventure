extends EnemyCharacter
## Base Mushroom - Sleeps until disturbed, then hunts the disturbance location
##
## DESIGN: "Moving to the disturbance"
## - Mushroom sleeps peacefully
## - Player triggers detection → disturbance_position captured HERE (memory)
## - Surprise state: wake up animation
## - Run state: if player visible → chase player directly; else → chase memory
## - Reach memory with no player → investigation complete → sleep

## The position where disturbance was detected (memory)
var disturbance_position: Vector2 = Vector2.ZERO
## Whether we have a valid disturbance to investigate
var has_disturbance: bool = false


func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Sleep)
	super._ready()


func _on_detect_player_area_body_entered(_body: Node2D) -> void:
	if fsm and fsm.current_state:
		fsm.current_state.change_state(fsm.states.explode)


func _on_player_in_sight(player_pos: Vector2) -> void:
	# Capture disturbance position at detection time (memory)
	disturbance_position = player_pos
	has_disturbance = true
	
	if fsm and fsm.current_state and fsm.current_state.name != "surprise" and fsm.current_state.name != "run":
		fsm.change_state(fsm.states.surprise)


func clear_disturbance() -> void:
	has_disturbance = false
