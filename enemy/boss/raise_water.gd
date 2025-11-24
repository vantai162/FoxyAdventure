extends EnemyState

## Phase 2 water manipulation attack
## Raises water to flood level or lowers it back, then returns to Idle

func _enter():
	obj.change_animation("skill2")
	_perform_water_action()

func _update(delta):
	pass

func _perform_water_action() -> void:
	var water_node = obj.get_water_node()
	if not water_node:
		push_warning("WarlordTurtle: No water node found for RaiseWater state")
		change_state(fsm.states.idle)
		return
	
	# Calculate target height relative to water node position
	var water_global_pos = water_node.global_position
	var target_surface_y: float
	
	if obj.water_raised:
		# Lower water back to normal
		target_surface_y = 0.5
		obj.water_raised = false
	else:
		# Raise water to configured target height
		# target_global_y = water_global_pos.y + target_surface_y
		# Solve for target_surface_y: target_surface_y = target_global_y - water_global_pos.y
		target_surface_y = obj.water_raise_target_y - water_global_pos.y
		obj.water_raised = true
	
	# Trigger water level change
	water_node.raise_water(target_surface_y, obj.water_raise_duration)
	obj.last_water_action_time = Time.get_ticks_msec() / 1000.0
	
	# Wait for animation + water transition to complete
	await get_tree().create_timer(obj.water_raise_duration + 0.5).timeout
	change_state(fsm.states.idle)
