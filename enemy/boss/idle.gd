extends EnemyState

func _enter():
	obj.change_animation("idle")
	# Randomize idle duration for unpredictability
	timer = randf_range(0.8, 1.5)
	
func _update(delta):
	if update_timer(delta):
		_choose_next_action()
	
	
	
func _choose_next_action() -> void:
	## Phase 1: Mostly Skill1 (bombs), occasionally Skill2 (rockets)
	## Phase 2: Randomly pick from [Skill1, Skill2, RaiseWater, SummonWhirlpool]
	##          RaiseWater requires cooldown, SummonWhirlpool requires water raised
	
		
	if obj.current_phase == 1:
		# 70% bombs, 30% rockets for some unpredictability
		if randf() < 0.7:
			change_state(fsm.states.skill1)
		else:
			change_state(fsm.states.skill2)
	else:
		var available_actions = [fsm.states.skill1, fsm.states.skill2]
		
		# Add water manipulation if cooldown allows
		var can_water = obj.can_use_water_action()
		var has_raise_state = fsm.states.has("raisewater")
		var has_whirlpool_state = fsm.states.has("summonwhirlpool")
		
		if can_water and has_raise_state:
			available_actions.append(fsm.states.raisewater)
		
		if obj.water_raised and has_whirlpool_state:
			available_actions.append(fsm.states.summonwhirlpool)
		
		var chosen_action = available_actions[randi() % available_actions.size()]
		change_state(chosen_action)
