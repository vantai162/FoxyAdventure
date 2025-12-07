extends EnemyCharacter
class_name EliteHunterCrab
## Elite Crab: "The Hunter"
## Aggressive pursuit with jump attacks when player detected

func _ready() -> void:
	# Initialize FSM FIRST (critical: before super._ready or any state logic)
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()
	
	# Enable player vision detection AFTER FSM is ready
	enable_check_player_in_sight()

# Override player detection to trigger hunt mode
func _on_player_in_sight(_player_pos: Vector2) -> void:
	if found_player:
		if found_player.global_position.x > global_position.x:
			change_direction(1)
		else:
			change_direction(-1)
	
	# Trigger hunt state if available
	if fsm and fsm.states.has("hunt"):
		if fsm.current_state == fsm.states.run:
			fsm.change_state(fsm.states.hunt)

func _on_player_not_in_sight() -> void:
	# Hunt state will timeout back to run automatically
	pass
