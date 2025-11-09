extends EnemyState

func _enter() -> void:
	obj.change_animation("attack")
	obj.perform_spear_attack()
	
	# Dim shield to show it's in background during attack
	obj.shield.modulate = Color(1, 1, 1, 0.4)
	
	var timer = get_tree().create_timer(obj.attack_animation_duration)
	timer.connect("timeout", Callable(self, "_on_animation_timer_finished"))

func _exit() -> void:
	# Restore shield opacity when leaving attack state
	obj.shield.modulate = Color(1, 1, 1, 1.0)

func _on_animation_timer_finished():
	if fsm.current_state == self:
		change_state(fsm.states.defend)
