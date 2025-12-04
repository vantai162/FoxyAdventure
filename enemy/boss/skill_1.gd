extends EnemyState

var shoot_time := 0.3
var shot := false

func _enter():
	obj.change_animation("skill1")
	timer = 1.0
	obj.invincible = true
	shot = false

func _update(delta):
	var finished = update_timer(delta)
	
	if not shot and timer <= (1.0 - shoot_time):
		obj.fire_boomb()
		shot = true

	if finished:
		change_state(fsm.states.idle)
		
func _exit():
	# QUAN TRỌNG: Đảm bảo Invincibility được tắt khi RỜI KHỎI trạng thái này
	obj.invincible = false
