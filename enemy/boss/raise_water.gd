extends EnemyState

## Phase 2 water manipulation attack
## Raises water to flood level (using water's raised_level) or lowers it back, then returns to Idle


func _enter():
	obj.change_animation("summon")
	_perform_water_action()
	#wave_sound.play()
	AudioManager.play_sound("warlord_raise_water",20.0)
	
func _update(delta):
	pass

func _perform_water_action() -> void:
	var water_node = obj.get_water_node()
	if not water_node:
		push_warning("WarlordTurtle: No water node found for RaiseWater state")
		change_state(fsm.states.idle)
		return
	
	if obj.water_raised:
		# Lower water back to normal surface_level
		water_node.return_to_normal(obj.water_raise_duration)
		obj.water_raised = false
	else:
		# Raise water to the configured raised_level on the water node
		# The water's raised_level should be set by the level designer
		water_node.raise_water(water_node.raised_level, obj.water_raise_duration)
		obj.water_raised = true
	
	obj.last_water_action_time = Time.get_ticks_msec() / 1000.0
	
	# Wait for animation + water transition to complete
	await get_tree().create_timer(obj.water_raise_duration).timeout
	if fsm.states.has("summonwhirlpool"):
		change_state(fsm.states.summonwhirlpool)
	else:
		change_state(fsm.states.idle)
