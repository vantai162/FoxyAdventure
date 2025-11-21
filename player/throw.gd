extends Player_State

func _enter() -> void:
	if obj.is_on_floor():
		obj.change_animation("attack")
	else:
		obj.change_animation("Jump_attack")
	
	timer = obj.throw_duration
	
	# Stop player on normal ground, but preserve momentum on ice
	if not (obj.is_on_floor() and obj._is_on_ice()):
		obj.velocity.x = 0
		
	obj.throw_blade_projectile()

func _exit() -> void:
	pass

func _update(delta: float) -> void:
	if update_timer(delta):
		change_state(fsm.previous_state)
