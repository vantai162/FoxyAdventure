extends EnemyState

## Throw coconuts at player from tree top - intense barrage attack
## 
## Attack patterns:
##   - Aimed shots directly at player
##   - Predictive shots ahead of player movement
##   - Burst volleys with varied timing to prevent easy rhythm dodging

enum ThrowPattern { AIMED, PREDICTIVE, SPREAD }

var throw_count: int = 0
var max_throws: int = 3
var time_since_throw: float = 0.0
var current_pattern: ThrowPattern = ThrowPattern.AIMED

@export var base_interval: float = 0.6  ## Base time between throws
@export var interval_variance: float = 0.3  ## Randomize timing to break rhythm
@export var coconut_speed: float = 350.0  ## How fast coconuts travel
@export var prediction_factor: float = 0.4  ## How much to lead the player

var next_interval: float = 0.0


func _enter() -> void:
	obj.change_animation("throw")
	throw_count = 0
	time_since_throw = 0.0
	
	# Phase 2: more throws, faster, more aggressive
	if obj.current_phase == 2:
		max_throws = 7
		base_interval = 0.45
		coconut_speed = 420.0
	else:
		max_throws = 4
	
	# Throw first one immediately
	_throw_coconut()
	throw_count += 1
	_randomize_next_interval()


func _update(delta: float) -> void:
	# Stay in the air - prevent gravity
	obj.velocity = Vector2.ZERO
	
	# Face the player while throwing
	if obj.found_player:
		var dir_to_player = sign(obj.found_player.global_position.x - obj.global_position.x)
		if dir_to_player != 0 and dir_to_player != obj.direction:
			obj.change_direction(dir_to_player)
	
	time_since_throw += delta
	
	if time_since_throw >= next_interval:
		_throw_coconut()
		throw_count += 1
		time_since_throw = 0.0
		_randomize_next_interval()
		
		if throw_count >= max_throws:
			_descend_and_return()


func _randomize_next_interval() -> void:
	## Vary timing to prevent player from getting into a comfortable dodge rhythm
	next_interval = base_interval + randf_range(-interval_variance, interval_variance)
	# Occasional quick double-tap
	if randf() < 0.2:
		next_interval *= 0.5


func _throw_coconut() -> void:
	if not obj.coconut_factory:
		return
	
	var coconut = obj.coconut_factory.create()
	if not coconut:
		return
	
	# Pick pattern - vary between aimed and predictive
	current_pattern = ThrowPattern.AIMED if randf() < 0.6 else ThrowPattern.PREDICTIVE
	
	var launch_velocity := _calculate_throw_velocity(coconut)
	
	if coconut.has_method("launch"):
		coconut.launch(launch_velocity)
	else:
		coconut.linear_velocity = launch_velocity


func _calculate_throw_velocity(coconut: Node2D) -> Vector2:
	if not obj.found_player:
		# No player - random spread
		return Vector2(randf_range(-200, 200), 100)
	
	var player_pos = obj.found_player.global_position
	var coconut_pos = coconut.global_position
	
	match current_pattern:
		ThrowPattern.AIMED:
			# Direct shot at current player position
			return _calculate_arc_to_target(coconut_pos, player_pos)
		
		ThrowPattern.PREDICTIVE:
			# Lead the player based on their velocity
			var player_vel = obj.found_player.velocity if obj.found_player.has_method("get") else Vector2.ZERO
			var predicted_pos = player_pos + player_vel * prediction_factor
			return _calculate_arc_to_target(coconut_pos, predicted_pos)
		
		_:
			return _calculate_arc_to_target(coconut_pos, player_pos)


func _calculate_arc_to_target(from: Vector2, to: Vector2) -> Vector2:
	## Calculate velocity to hit target with a nice arc
	var diff = to - from
	var distance = diff.length()
	
	# Time to reach target (based on horizontal distance and speed)
	var time_to_target = abs(diff.x) / coconut_speed if abs(diff.x) > 10 else 0.5
	time_to_target = clamp(time_to_target, 0.3, 1.5)
	
	# Horizontal velocity
	var vx = diff.x / time_to_target
	
	# Vertical velocity accounting for gravity (assuming ~980 gravity)
	# Using kinematic equation: y = vy*t + 0.5*g*t^2
	# Solve for vy: vy = (y - 0.5*g*t^2) / t
	var gravity = 980.0
	var vy = (diff.y - 0.5 * gravity * time_to_target * time_to_target) / time_to_target
	
	return Vector2(vx, vy)


func _descend_and_return() -> void:
	# Reset rotation before descending
	obj.get_node("Direction").rotation_degrees = 0.0
	
	# Get ground Y from metadata (stored by climb_tree)
	var target_y = obj.global_position.y + 150.0  # Fallback
	if obj.has_meta("ground_y"):
		target_y = obj.get_meta("ground_y")
	
	var tween = obj.create_tween()
	tween.tween_property(obj, "global_position:y", target_y, 0.5)
	tween.tween_callback(_on_descent_complete)


func _on_descent_complete() -> void:
	change_state(fsm.states.idle)
