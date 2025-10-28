extends EnemyState

var hide_timer := 0.0

func _enter():
	obj.change_animation("hide")
	obj.velocity = Vector2.ZERO
	hide_timer = 0.0
	if obj.has_node("HurtArea2d"):
		var hurt_area = obj.get_node("HurtArea2d")
		hurt_area.set_deferred("monitoring", false)
		hurt_area.set_deferred("monitorable", false)
		
func _update(delta: float) -> void:
	hide_timer += delta
	if hide_timer >= 3.0:
		change_state(fsm.default_state)

func _exit() -> void:
	if obj.has_node("HurtArea2d"):
		var hurt_area = obj.get_node("HurtArea2d")
		hurt_area.set_deferred("monitoring", true)
		hurt_area.set_deferred("monitorable", true)
