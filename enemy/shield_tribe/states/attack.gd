extends EnemyState

func _enter() -> void:
	obj.change_animation("attack")
	obj.perform_spear_attack()
	
	var timer = get_tree().create_timer(obj.attack_animation_duration)
	timer.connect("timeout", Callable(self, "_on_animation_timer_finished"))

func _exit() -> void:
	pass

func _on_animation_timer_finished():
	if fsm.current_state == self:
		change_state(fsm.states.defend)

