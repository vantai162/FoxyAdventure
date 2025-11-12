extends EnemyCharacter

func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()

func _on_player_in_sight(_player_pos: Vector2) -> void:
	if fsm.current_state.name != "surprise" and fsm.current_state.name != "flee":
		fsm.change_state(fsm.states.surprise)

func _on_player_not_in_sight() -> void:
	if fsm.current_state.name == "flee" or fsm.current_state.name == "surprise":
		fsm.change_state(fsm.states.run)
