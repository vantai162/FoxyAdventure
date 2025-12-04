extends EnemyState

func _enter():
	obj.change_animation("skill2")
	obj.invincible = true
	_run_skill()
	
func _update(delta):
	pass

func _run_skill() -> void:
	await get_tree().create_timer(0.5).timeout
	if fsm.current_state == self:
		obj.fire_rocket()
	await get_tree().create_timer(1.5).timeout
	if fsm.current_state == self:
		change_state(fsm.states.idle)

func _exit():
	# QUAN TRỌNG: Đảm bảo Invincibility được tắt khi RỜI KHỎI trạng thái này
	# (Dù là chuyển sang idle, hurt, hay dead)
	obj.invincible = false
