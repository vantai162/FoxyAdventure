extends EnemyState
## Elite Bombardier pursue state
## Actively moves toward player, attacks when in range

@export var attack_range: float = 200.0  ## Distance to trigger attack
@export var min_attack_range: float = 80.0  ## Too close, back up

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
	
	# Distance-based behavior
	if distance < min_attack_range:
		# Too close! Back up (reverse direction movement)
		obj.velocity.x = -obj.direction * obj.movement_speed * 0.5
	elif distance > attack_range:
		# Too far, close distance
		obj.velocity.x = obj.direction * obj.movement_speed
	else:
		# In attack range, stop and attack
		obj.velocity.x = 0
		if obj.attack_timer.is_stopped():
			obj._on_attack_timer_timeout()
		return
	
	# Respect walls and edges
	if obj.is_touch_wall():
		obj.velocity.x = 0
		# Attack even if blocked by terrain
		if obj.attack_timer.is_stopped():
			obj._on_attack_timer_timeout()
	elif obj.is_on_floor() and obj.is_can_fall():
		obj.velocity.x = 0
