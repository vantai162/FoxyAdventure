extends EnemyState
## Elite Crab "Hunter" hunt state
## Aggressive pursuit with jump attacks toward player
## DESIGN: Smart pursuit with unreachable target detection (no oscillation!)

@export var hunt_speed_multiplier: float = 1.4  ## 40% faster when hunting
@export var jump_cooldown: float = 2.0  ## Time between jump attacks
@export var jump_distance_threshold: float = 80.0  ## Jump when this close to player
@export var jump_distance_max: float = 200.0  ## Don't jump if player too far
@export var detection_timeout: float = 4.0  ## Return to run if player not seen

## Unreachable target detection (prevent oscillation under player)
@export var unreachable_vertical_threshold: float = 80.0  ## Too high = unreachable
@export var unreachable_horizontal_threshold: float = 40.0  ## Too narrow = directly overhead

var jump_timer: float = 0.0
var detection_timer: float = 0.0

func _enter() -> void:
	obj.change_animation("run")
	jump_timer = 0.0  # Can jump immediately on entry
	detection_timer = detection_timeout

func _update(delta: float) -> void:
	# Update timers
	if jump_timer > 0.0:
		jump_timer -= delta
	
	# Check if player still visible
	if obj.found_player and is_instance_valid(obj.found_player):
		detection_timer = detection_timeout  # Reset timer
		_hunt_player(delta)
	else:
		detection_timer -= delta
		if detection_timer <= 0.0:
			# Lost player, return to patrol
			change_state(fsm.states.run)
			return
		# Keep moving while searching
		obj.velocity.x = obj.direction * obj.movement_speed
		
		# Only turn at obstacles when NOT actively hunting
		if _should_turn_around():
			obj.turn_around()

func _hunt_player(delta: float) -> void:
	## Pursue player with jump attacks (with unreachable target detection)
	var to_player = obj.found_player.global_position - obj.global_position
	var horizontal_distance = abs(to_player.x)
	var vertical_distance = to_player.y  # Negative if player is above
	
	# CRITICAL: Check if target is unreachable (player directly above with minimal horizontal offset)
	# This prevents oscillation when player stands on crab's head
	if vertical_distance < -unreachable_vertical_threshold and horizontal_distance < unreachable_horizontal_threshold:
		# Player is high above us and almost directly overhead - unreachable!
		change_state(fsm.states.run)
		return
	
	# Face player (this overrides wall-turn behavior intentionally)
	if to_player.x > 0 and obj.direction < 0:
		obj.turn_around()
	elif to_player.x < 0 and obj.direction > 0:
		obj.turn_around()
	
	# Handle wall obstacles: if touching wall and player is behind us, don't override
	if obj.is_touch_wall():
		# Check if player is actually on the other side of the wall
		var player_direction = sign(to_player.x)
		if player_direction != obj.direction:
			# Player is behind us but we hit a wall - they're on the other side
			# Don't flip back and forth, just stop and wait/jump
			obj.velocity.x = 0
			# Try to jump over the obstacle if player is reasonably close
			if obj.is_on_floor() and jump_timer <= 0.0 and horizontal_distance <= jump_distance_max:
				_perform_jump_attack(to_player)
			return
	
	# Move toward player (faster than patrol)
	obj.velocity.x = obj.direction * obj.movement_speed * hunt_speed_multiplier
	
	# Jump attack logic: more aggressive when player is above
	if obj.is_on_floor() and jump_timer <= 0.0:
		# Jump if player is above us (even if far horizontally)
		if vertical_distance < -50.0 and horizontal_distance <= jump_distance_max * 1.5:
			_perform_jump_attack(to_player)
		# Or jump if in horizontal range
		elif horizontal_distance >= jump_distance_threshold and horizontal_distance <= jump_distance_max:
			_perform_jump_attack(to_player)

func _perform_jump_attack(to_player: Vector2) -> void:
	## Jump toward player with aggressive arc (scales with vertical distance)
	var vertical_distance = abs(to_player.y)
	
	# Scale jump height based on how high player is (0.8x to 1.2x)
	var height_multiplier = clamp(0.8 + (vertical_distance / 200.0), 0.8, 1.2)
	var jump_height = obj.jump_speed * height_multiplier
	obj.velocity.y = -jump_height
	
	# Add horizontal boost toward player (lunge effect)
	var horizontal_boost = sign(to_player.x) * obj.movement_speed * 1.5
	obj.velocity.x += horizontal_boost
	
	jump_timer = jump_cooldown

func _should_turn_around() -> bool:
	## Standard crab turn-around logic
	if obj.is_touch_wall():
		return true
	if obj.is_on_floor() and obj.is_can_fall():
		return true
	return false
