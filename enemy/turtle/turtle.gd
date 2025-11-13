extends EnemyCharacter

func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()

func _on_hurt_area_2d_hurt(_direction: Vector2, _damage: float) -> void:
	fsm.change_state(fsm.states.hurt)
