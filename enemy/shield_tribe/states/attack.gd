extends EnemyState
## Attack state: Darkens shield, thrusts spear with tween animation.
## Returns to defend after attack completes.

func _enter() -> void:
	obj.change_animation("attack")
	obj.darken_shield()
	obj.perform_spear_attack()
	
	var timer = get_tree().create_timer(obj.attack_animation_duration)
	timer.connect("timeout", Callable(self, "_on_animation_timer_finished"))

func _exit() -> void:
	obj.restore_shield_color()

func _on_animation_timer_finished():
	if fsm.current_state == self:
		change_state(fsm.states.defend)
