extends Player_State

func _enter():
	obj.change_animation("run")
	obj.gravity = obj.swim_gravity       

func _update(delta: float):
	control_swimming()
	
	# Check if head is underwater before depleting oxygen
	if obj.current_water != null:
		# Head Y position (subtracting offset because Y increases downward in Godot)
		var head_y = obj.global_position.y - obj.head_offset_y
		var water_surface_y = obj.current_water.get_water_surface_global_y()
		
		# If head_y > water_surface_y, head is deeper (further down = more positive Y)
		if head_y > water_surface_y:
			# Head is underwater - deplete oxygen
			obj.current_oxygen -= obj.oxygen_decrease_rate * delta
			if obj.current_oxygen <= 0:
				obj.current_oxygen = 0
				fsm.current_state.take_damage(1)
		else:
			# Head is above water surface - restore oxygen
			obj.current_oxygen = min(obj.max_oxygen, obj.current_oxygen + obj.oxygen_increase_rate * delta)
	
	if not obj.is_in_water:
		fsm.change_state(fsm.states.fall)
	
