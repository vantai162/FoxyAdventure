extends Player_State

func _enter() -> void:
	obj.velocity.x=0
	obj.change_animation("idle")

func _update(delta: float) -> void:
	obj.current_oxygen = min(obj.max_oxygen, obj.current_oxygen + 1.5 * delta)
	if(obj.Effect["Stun"]<=0):
		control_throw()
		control_attack()
		control_moving()
		control_jump()
	if not obj.is_on_floor():
		change_state(fsm.states.fall)
	if(Input.is_action_just_pressed("kill")):
		if(obj.health > 0):
			change_state(fsm.states.hurt)
			take_damage(1)
			print(obj.health)
		if(obj.health < 1):
			change_state(fsm.states.dead)
