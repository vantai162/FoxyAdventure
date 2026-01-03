class_name Player_State
extends FSMState

## Shared scale tween for squash/stretch animations
## Only one scale tween should be active at a time to prevent conflicts
var _scale_tween: Tween = null

## Get direction-preserving scale vector
## CRITICAL: Direction node uses scale.x sign for facing direction
## scale.x < 0 = facing left, scale.x > 0 = facing right
## All squash/stretch must use this to avoid moonwalking!
func _get_directional_scale(base_scale: Vector2) -> Vector2:
	var direction_node = obj.get_node_or_null("Direction")
	if not direction_node:
		return base_scale
	var facing = sign(direction_node.scale.x) if direction_node.scale.x != 0 else 1.0
	return Vector2(facing * base_scale.x, base_scale.y)


## Kill any active scale tween and reset scale to normal
## Call this in _exit() of states that use squash/stretch
## CRITICAL: Preserves direction sign (scale.x negative = facing left)
func _cleanup_scale_tween() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = null
	var direction_node = obj.get_node_or_null("Direction")
	if direction_node:
		# Preserve facing direction! scale.x sign = direction
		var facing = sign(direction_node.scale.x) if direction_node.scale.x != 0 else 1.0
		direction_node.scale = Vector2(facing * 1.0, 1.0)


## Create a managed scale tween — kills previous tween first
func _create_scale_tween() -> Tween:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	return _scale_tween


func control_moving() -> bool:
	if(GameManager.paused):
		return false
	var dir: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	var is_moving: bool = abs(dir) > 0.1
	if obj.is_on_floor() and Input.is_action_pressed("down") and obj._is_on_one_way_platform():
		obj.drop_down_platform()
	var final_speed = obj.movement_speed
	if obj.Effect["Slow"] > 0:
		final_speed *= obj.slow_effect_multiplier
	# Initialize current_speed if it's been reset (0 means player stopped)
	if obj.current_speed == 0:
		obj.current_speed = final_speed
	
	# MOVING input detected
	if is_moving:
		dir = sign(dir)
		obj.change_direction(dir)
		var target_velocity_x = obj.current_speed * dir
		if obj.wind_velocity != Vector2.ZERO:
			target_velocity_x += obj.wind_velocity.x
		
		# Ground movement (ice vs normal)
		if obj.is_on_floor():
			if obj._is_on_ice():
				# Ice: slower acceleration (slippery feel)
				obj.velocity.x = lerp(obj.velocity.x, target_velocity_x, obj.accelecrationValue)
			else:
				# Normal ground: responsive friction
				obj.velocity.x = lerp(obj.velocity.x, target_velocity_x, obj.ground_friction)
			change_state(fsm.states.run)
			return true
		else:
			# Air movement: player has input, steering against momentum
			# Check if player is moving WITH an impulse (same direction)
			var input_dir = int(dir)
			var impulse_mult = obj.get_impulse_momentum_multiplier(input_dir)
			
			if impulse_mult < 1.0 and sign(obj.velocity.x) == sign(dir):
				# Player is steering with the impulse and momentum is preserved
				# Only accelerate if target is faster than current (don't brake)
				if abs(target_velocity_x) > abs(obj.velocity.x):
					obj.velocity.x = lerp(obj.velocity.x, target_velocity_x, obj.get_current_air_acceleration())
				# else: keep current impulse velocity, don't slow down
			else:
				# Normal air control (no impulse, or player fighting against impulse)
				obj.velocity.x = lerp(obj.velocity.x, target_velocity_x, obj.get_current_air_acceleration())
	
	# NOT MOVING - deceleration paths
	elif not is_moving:
		if obj.is_on_floor() and obj._is_on_ice():
			# Ice sliding: slow deceleration with optional wind
			var stop_target = 0.0
			if obj.wind_velocity != Vector2.ZERO:
				stop_target = obj.wind_velocity.x
			obj.velocity.x = lerp(obj.velocity.x, stop_target, obj.slideValue)
			if abs(obj.velocity.x) < obj.fullStopValue and obj.wind_velocity == Vector2.ZERO:
				obj.velocity.x = 0
				obj.current_speed = 0  # Reset speed when fully stopped
		elif obj.wind_velocity != Vector2.ZERO:
			# Wind influence (any surface)
			obj.velocity.x = lerp(obj.velocity.x, obj.wind_velocity.x, obj.wind_influence_factor)
		elif obj.is_on_floor():
			# Normal ground stop
			obj.velocity.x = lerp(obj.velocity.x, 0.0, obj.ground_friction)
			if abs(obj.velocity.x) < obj.min_stop_speed:
				obj.velocity.x = 0
			obj.current_speed = 0
		else:
			# Air drag: no input, natural momentum coast
			# Apply impulse momentum preservation (reduces/eliminates braking during impulse)
			var impulse_mult = obj.get_impulse_momentum_multiplier(0)  # 0 = no input direction
			var effective_decel = obj.air_deceleration * impulse_mult
			obj.velocity.x = lerp(obj.velocity.x, 0.0, effective_decel)
	
	return false
func control_jump() -> bool:
	if(GameManager.paused):
		return false
	if (Input.is_action_just_pressed("jump") and obj.jump_count < 2) or (obj._checkbuffer() and obj.is_on_floor()):
		if(obj.jump_count==0&& fsm.current_state==fsm.states.fall):
			obj.jump_count=1
		if state_sound:
			obj.play_sfx(state_sound)
		if obj.jump_count == 1:
			obj.jump(obj.jump_speed * obj.double_jump_power_multiplier)
		else:
			obj.jump(obj.jump_speed)
		obj.jump_count += 1
		change_state(fsm.states.jump)
		return true
	return false

func control_attack() -> bool:
	if(GameManager.paused):
		return false
	if Input.is_action_just_pressed("attack") and obj.can_attack():
		change_state(fsm.states.attack)
		return true
	return false

func control_throw() -> bool:
	if(GameManager.paused):
		return false
	if Input.is_action_just_pressed("throw_blade") and obj.can_throw_blade():
		change_state(fsm.states.throw)
		return true
	return false

func control_dash() -> bool:
	if(GameManager.paused):
		return false
	if obj.CoolDown["Dash"] > 0:
		return false
	if Input.is_action_just_pressed("dash"):
		if obj.is_on_floor():
			change_state(fsm.states.dash)
			return true
		elif not obj.dashed_on_air:
			change_state(fsm.states.dash)
			return true
		else:
			return false
	return false


func control_swimming() -> bool:
	if GameManager.paused:
		return false

	# Thoát khỏi nước
	if not obj.is_in_water:
		change_state(fsm.states.idle)
		return true

	var input_vec = Vector2.ZERO
	input_vec.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	input_vec.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	# Không bơi = đứng/treo trong nước
	if input_vec == Vector2.ZERO:
		obj.velocity = obj.velocity.lerp(Vector2.ZERO, obj.swim_deceleration)
		return false

	input_vec = input_vec.normalized()

	obj.change_direction(sign(input_vec.x) if input_vec.x != 0 else obj.direction)

	obj.velocity = obj.velocity.lerp(
		 input_vec * obj.swim_speed,
		obj.swim_acceleration
	)
	return true


func take_damage(damage: int) -> void:
	obj.take_damage(damage)
	
	if obj.health <= 0:
		obj.emit_signal("died")
		change_state(fsm.states.dead)
	else:
		change_state(fsm.states.hurt)
