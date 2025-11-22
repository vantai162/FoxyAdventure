extends EnemyState

var shoot_time := 0.3
var shot := false

func _enter():
	obj.change_animation("skill1")
	timer = 1.0  # tổng thời gian state skill1
	shot = false

func _update(delta):
	if not shot and timer <= (1.0 - shoot_time):
		obj.fire_boomb()
		shot = true

	if update_timer(delta):
		change_state(fsm.states.idle)
