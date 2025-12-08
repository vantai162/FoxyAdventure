extends EnemyState
## Elite Starfish Run State
## CRITICAL: Overrides base run.gd to use RicochetDash instead of Attack
## Base starfish uses: change_state(fsm.states.attack)
## Elite starfish must use: change_state(fsm.states.ricochetdash)
## Note: FSM normalizes state node names to lowercase ("RicochetDash" → "ricochetdash")

func _enter() -> void:
	obj.change_animation("run")

func _update(_delta: float) -> void:
	super._update(_delta)
	
	obj.velocity.x = obj.direction * obj.movement_speed
	
	if _should_turn_around():
		obj.turn_around()

	if obj.found_player:
		if obj.found_player.global_position.x > obj.global_position.x:
			obj.turn_right()
		else:
			obj.turn_left()
		
		# Only trigger ricochetdash if NOT in sequence and cooldown expired
		# This prevents elite_run from competing with the signal-based trigger
		if fsm.states.has("ricochetdash"):
			# Check parent's sequence flag to prevent mid-sequence re-trigger
			if "is_in_sequence" in obj and obj.is_in_sequence:
				return  # Sequence in progress, don't interrupt
			if "attack_cooldown_timer" in obj and obj.attack_cooldown_timer > 0.0:
				return  # Cooldown active, don't trigger yet
			change_state(fsm.states.ricochetdash)

func _should_turn_around() -> bool:
	if obj.is_touch_wall():
		return true
	if obj.is_on_floor() and obj.is_can_fall():
		return true
	return false
