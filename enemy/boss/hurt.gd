extends EnemyState


func _enter():
	obj.health_changed.emit()
	obj.change_animation("hurt")
	timer = 0.2
	
	# Check for phase 2 transition (50% health threshold)
	if obj.current_phase == 1 and obj.health <= obj.max_health / 2:
		# Use phase_transition state if available, otherwise instant transition
		if fsm.states.has("phasetransition"):
			change_state(fsm.states.phasetransition)
			return
		else:
			obj.current_phase = 2
			print("PHASE 2 (instant)")
	
	if obj.health <= 1:
			change_state(fsm.states.vulnerable)

func _update( delta: float):
	if update_timer(delta):
		if obj.health <= 0:
			change_state(fsm.states.dead)
		else:
			change_state(fsm.default_state)
