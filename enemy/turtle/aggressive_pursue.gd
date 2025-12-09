extends EnemyState
## Elite Spiny Turtle aggressive pursue state
## Aggressive charger: Same speed as elite crab, smart pursuit with spike burst attack
## Design: Tension through speed + area detection + frequent attacks, NOT recklessness

@export var pursue_speed_multiplier: float = 1.4  ## Match elite crab speed (40% faster)
@export var hide_trigger_range: float = 120.0  ## Spike burst range (moderate threat zone)
@export var detection_timeout: float = 4.0  ## Return to run if player not seen

var detection_timer: float = 0.0

func _enter() -> void:
	obj.change_animation("run")
	detection_timer = detection_timeout

func _update(delta: float) -> void:
	# Check if player still visible (like elite crab hunt state)
	if obj.found_player and is_instance_valid(obj.found_player):
		detection_timer = detection_timeout  # Reset timer
		_pursue_player(delta)
	else:
		detection_timer -= delta
		if detection_timer <= 0.0:
			# Lost player, return to patrol
			change_state(fsm.states.run)
			return
		# Keep moving while searching
		obj.velocity.x = obj.direction * obj.movement_speed
		
		# Turn at obstacles when NOT actively pursuing
		if obj.is_touch_wall():
			obj.turn_around()

func _pursue_player(delta: float) -> void:
	## RELENTLESS pursuit - no edge caution, just CHARGE
	var to_player = obj.found_player.global_position - obj.global_position
	var horizontal_distance = abs(to_player.x)
	
	# Face player (overrides wall-turn intentionally)
	if to_player.x > 0 and obj.direction < 0:
		obj.turn_around()
	elif to_player.x < 0 and obj.direction > 0:
		obj.turn_around()
	
	# ATTACK RANGE: Trigger spike burst at LONGER range (more threatening than crab)
	if horizontal_distance < hide_trigger_range and obj.can_burst():
		if fsm.states.has("offensivehide"):
			change_state(fsm.states.offensivehide)
		return
	
	# Handle wall obstacles (only stop if player behind wall)
	if obj.is_touch_wall():
		var player_direction = sign(to_player.x)
		if player_direction != obj.direction:
			# Player behind wall - stop and attack if in range
			obj.velocity.x = 0
			if horizontal_distance <= hide_trigger_range * 1.2 and obj.can_burst():
				if fsm.states.has("offensivehide"):
					change_state(fsm.states.offensivehide)
			return
	
	# SMART EDGE BEHAVIOR: Fall off edge ONLY if player is below (pursuing downward)
	# Otherwise stop (don't suicide off edges when player is on same level)
	if obj.is_on_floor() and obj.is_can_fall():
		var vertical_distance = to_player.y
		if vertical_distance < 50.0:  # Player NOT significantly below
			# Stop at edge, try to attack if in range
			obj.velocity.x = 0
			if horizontal_distance <= hide_trigger_range * 1.2 and obj.can_burst():
				if fsm.states.has("offensivehide"):
					change_state(fsm.states.offensivehide)
			return
		# Player IS below - commit to chase (fall off pursuing)
	
	# Move toward player - aggressive pursuit (match elite crab speed)
	obj.velocity.x = obj.direction * obj.movement_speed * pursue_speed_multiplier
