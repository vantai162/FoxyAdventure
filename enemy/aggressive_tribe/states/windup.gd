extends EnemyState

func _enter() -> void:
	obj.change_animation("idle")
	obj.velocity.x = 0
	
	# Face player during windup
	if obj.found_player:
		if obj.found_player.global_position.x > obj.global_position.x:
			obj.change_direction(1)
		else:
			obj.change_direction(-1)
	
	obj.windup_timer.start()

func _update(_delta: float) -> void:
	obj.velocity.x = 0

func _exit() -> void:
	obj.windup_timer.stop()

func _on_windup_timer_timeout() -> void:
	if fsm.current_state == self:
		change_state(fsm.states.attack)
