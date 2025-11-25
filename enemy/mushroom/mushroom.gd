extends EnemyCharacter



func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Sleep)
	super._ready()
	invincible = true


func _on_detect_player_area_body_entered(body: Node2D) -> void:
	fsm.current_state.change_state(fsm.states.explode)


func _on_player_in_sight(_player_pos: Vector2) -> void:
	if fsm.current_state.name != "surprise" and fsm.current_state.name != "run":
		fsm.change_state(fsm.states.surprise)
