extends EnemyCharacter


func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()



func _on_detect_player_area_body_entered(body: Node2D) -> void:
	fsm.current_state.change_state(fsm.states.explode)
