extends EnemyState
## Elite Spiny Turtle aggressive pursue state
## Charges toward player, triggers defensive hide when in melee range

@export var hide_trigger_range: float = 100.0  ## Distance to trigger defensive hide

func _enter() -> void:
	obj.change_animation("run")

func _update(_delta: float) -> void:
	if not obj.found_player or not is_instance_valid(obj.found_player):
		# Lost player, return to patrol
		change_state(fsm.states.run)
		return
	
	var to_player = obj.found_player.global_position - obj.global_position
	var distance = abs(to_player.x)
	
	# Face player
	if to_player.x > 0 and obj.direction != 1:
		obj.change_direction(1)
	elif to_player.x < 0 and obj.direction != -1:
		obj.change_direction(-1)
	
	# Close range: Trigger defensive hide (spike burst)
	if distance < hide_trigger_range:
		if fsm.states.has("defensivehide"):
			change_state(fsm.states.defensivehide)
		elif fsm.states.has("hide"):
			change_state(fsm.states.hide)  # Fallback
		return
	
	# Move toward player aggressively
	obj.velocity.x = obj.direction * obj.movement_speed
	
	# Respect walls and edges
	if obj.is_touch_wall():
		obj.velocity.x = 0
		# Trigger hide if blocked by terrain
		if fsm.states.has("defensivehide"):
			change_state(fsm.states.defensivehide)
	elif obj.is_on_floor() and obj.is_can_fall():
		obj.velocity.x = 0
