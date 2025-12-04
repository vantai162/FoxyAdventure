extends EnemyState

func _enter():
	obj.change_animation("skill2")
	_run_skill()

func _update(delta):
	pass

func _run_skill() -> void:
	await get_tree().create_timer(0.5).timeout
	if fsm.current_state == self:
		obj.fire_rocket()
	await get_tree().create_timer(1.5).timeout
	obj.invincible_timer = obj.max_invincible
	if fsm.current_state == self:
		change_state(fsm.states.idle)
