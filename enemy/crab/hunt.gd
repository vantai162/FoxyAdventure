extends EnemyState
## Elite Crab "Hunter" hunt state
## Aggressive pursuit with jump attacks toward player

@export var hunt_speed_multiplier: float = 1.4  ## 40% faster when hunting
@export var jump_cooldown: float = 2.0  ## Time between jump attacks
@export var jump_distance_threshold: float = 80.0  ## Jump when this close to player
@export var jump_distance_max: float = 200.0  ## Don't jump if player too far
@export var detection_timeout: float = 4.0  ## Return to run if player not seen

var jump_timer: float = 0.0
var detection_timer: float = 0.0

func _enter() -> void:
	obj.change_animation("run")
	jump_timer = 0.0  # Can jump immediately on entry
	detection_timer = detection_timeout

func _update(delta: float) -> void:
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

	# Update jump cooldown
	if jump_timer > 0.0:
		jump_timer -= delta

	# Standard collision checks
	if _should_turn_around():
		obj.turn_around()

func _hunt_player(delta: float) -> void:
	## Pursue player with jump attacks
	var to_player = obj.found_player.global_position - obj.global_position
	var distance = abs(to_player.x)
	
	# Face player
	if to_player.x > 0 and obj.direction < 0:
		obj.turn_around()
	elif to_player.x < 0 and obj.direction > 0:
		obj.turn_around()
	
	# Move toward player (faster than patrol)
	obj.velocity.x = obj.direction * obj.movement_speed * hunt_speed_multiplier
	
	# Jump attack if in range and on ground
	if obj.is_on_floor() and jump_timer <= 0.0:
		if distance >= jump_distance_threshold and distance <= jump_distance_max:
			_perform_jump_attack(to_player)

func _perform_jump_attack(to_player: Vector2) -> void:
	## Jump toward player with aggressive arc
	# Reduced jump height for aggressive lunge
	var jump_height = obj.jump_speed * 0.8
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
