extends Player_State

func _enter():
	obj.change_animation("run")
	obj.gravity = obj.swim_gravity       

func _update(delta: float):
	control_swimming()
	
	# Check if head is underwater before depleting oxygen
	if obj.is_head_underwater():
		# Head is underwater - deplete oxygen
		obj.current_oxygen -= obj.oxygen_decrease_rate * delta
		if obj.current_oxygen <= 0:
			obj.current_oxygen = 0
			fsm.current_state.take_damage(1)
			obj.health_changed.emit()
	elif obj.current_water != null:
		# Head is above water surface - restore oxygen
		obj.current_oxygen = min(obj.max_oxygen, obj.current_oxygen + obj.oxygen_increase_rate * delta)
	
	# Exit swim state if no longer in water OR if head is above water (whirlpool air pockets)
	if not obj.is_in_water:
		fsm.change_state(fsm.states.fall)
	elif not obj.is_head_underwater() and obj.is_on_floor():
		# Standing in air pocket (like whirlpool depression) - return to ground movement
		fsm.change_state(fsm.states.idle)
	
