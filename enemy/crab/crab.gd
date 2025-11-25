extends EnemyCharacter


func _ready() -> void:
	super._ready()
	invincible = true


func _on_active_area_2d_body_entered(body: Node2D) -> void:
	fsm = FSM.new(self, $States, $States/Run)
