extends Player_State

func _enter() -> void:
	# Don't force velocity to 0 - let control_moving() handle deceleration
	# This allows ice sliding and other physics to work naturally
	obj.change_animation("idle")

func _update(delta: float) -> void:
	obj.current_oxygen = min(obj.max_oxygen, obj.current_oxygen + obj.oxygen_increase_rate * delta)
	if obj.Effect["Stun"] <= 0:
		control_throw()
		control_attack()
		control_moving()
		control_jump()
	if not obj.is_on_floor():
		change_state(fsm.states.fall)
