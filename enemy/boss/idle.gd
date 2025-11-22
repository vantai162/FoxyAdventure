extends EnemyState
func _enter():
	obj.change_animation("idle")
	timer = 2.0        # nghỉ 1 giây

func _update(delta):
	if update_timer(delta):
		obj.fire_boomb()
