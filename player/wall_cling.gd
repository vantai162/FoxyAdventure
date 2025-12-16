extends Player_State

## ============================================================================
## WALL CLING STATE - 3-Phase Accelerating Slide System
## ============================================================================
## Designed with intent: "An act requires activeness."
## 
## The player must HOLD TOWARD the wall to cling. No AFK wall clinging.
## Release input = immediate fall. This creates commitment and skill expression.
##
## THREE PHASES OF WALL GRIP:
## 1. GRIP PHASE: Strong initial grip, minimal slide (fingers digging in)
## 2. FATIGUE PHASE: Accelerating slide as grip weakens (woah woah woah!)
## 3. SLIP PHASE: Terminal velocity reached, you're toast
##
## Wall jump RESETS the grip timer - rewards aggressive, skilled play.
## ============================================================================

## Time spent clinging since last grip reset
var cling_time: float = 0.0

## Cache the wall direction for consistent checking
var wall_direction: int = 0  ## 1 = wall on right, -1 = wall on left

func _enter() -> void:
	obj.change_animation("jump")
	obj.jump_count = 0
	obj.dashed_on_air = false
	
	# Reset grip timer on entry (fresh cling = fresh grip)
	cling_time = 0.0
	
	# Determine which side the wall is on
	wall_direction = _detect_wall_direction()

func _exit() -> void:
	# Clean up state
	wall_direction = 0

func _update(delta: float):
	# ========================================
	# PRIORITY 1: Ice check (can't grip ice!)
	# ========================================
	if obj._is_wall_ice():
		change_state(fsm.states.fall)
		return
	
	# ========================================
	# PRIORITY 2: Input validation
	# ========================================
	# Must be holding toward wall to maintain cling
	if obj.wall_cling_requires_input and not _is_holding_toward_wall():
		# Player released - respect their intent, let them fall
		change_state(fsm.states.fall)
		return
	
	# ========================================
	# PRIORITY 3: Wall jump (highest priority action)
	# ========================================
	if Input.is_action_just_pressed("jump"):
		# Wall jump! Launch away from wall
		obj.velocity.x = -obj.direction * obj.wall_jump_force
		obj.velocity.y = -obj.jump_speed
		obj.change_direction(-obj.direction)
		obj.jump_count = 1
		change_state(fsm.states.jump)
		return
	
	# ========================================
	# PRIORITY 4: Check if still on wall
	# ========================================
	if not obj.is_on_wall():
		if not obj.is_on_floor():
			change_state(fsm.states.fall)
		else:
			change_state(fsm.states.idle)
		return
	
	# ========================================
	# PHYSICS: 3-Phase Accelerating Slide
	# ========================================
	cling_time += delta
	
	var slide_velocity: float = _calculate_slide_velocity()
	
	# Only apply slide if not moving up (ascending from wall jump)
	if obj.velocity.y >= 0:
		obj.velocity.y = slide_velocity
	
	# Prevent horizontal drift - lock to wall
	# Small push toward wall to maintain contact
	obj.velocity.x = obj.direction * 5.0

## ============================================================================
## HELPER: Detect which side the wall is on
## ============================================================================
## Returns 1 if wall is on right, -1 if wall is on left, 0 if no wall
func _detect_wall_direction() -> int:
	for i in obj.get_slide_collision_count():
		var collision = obj.get_slide_collision(i)
		var normal = collision.get_normal()
		
		# Horizontal collision = wall
		if abs(normal.x) > 0.5:
			# Wall normal points AWAY from wall
			# If normal.x > 0, wall is to the LEFT (player facing left toward wall)
			# If normal.x < 0, wall is to the RIGHT (player facing right toward wall)
			return -int(sign(normal.x))
	
	return 0

## ============================================================================
## HELPER: Check if player is holding input toward the wall
## ============================================================================
## This is the key to "active" wall cling - no input = no cling
func _is_holding_toward_wall() -> bool:
	var input_dir = Input.get_action_strength("right") - Input.get_action_strength("left")
	
	# Need meaningful input (not just floating point noise)
	if abs(input_dir) < 0.1:
		return false
	
	# Wall is on right (wall_direction = 1) → need to press right (input_dir > 0)
	# Wall is on left (wall_direction = -1) → need to press left (input_dir < 0)
	# We check that sign of input matches the wall direction
	return sign(input_dir) == wall_direction

## ============================================================================
## HELPER: Calculate slide velocity based on cling phase
## ============================================================================
## Three phases create the "grip → fatigue → slip" arc of mounting tension
func _calculate_slide_velocity() -> float:
	var grip_duration = obj.wall_grip_phase_duration
	var fatigue_duration = obj.wall_fatigue_phase_duration
	var grip_speed = obj.wall_grip_slide_speed
	var initial_speed = obj.wall_initial_slide_speed
	var max_speed = obj.wall_max_slide_speed
	
	if cling_time < grip_duration:
		# =====================================
		# PHASE 1: GRIP (firm hold, barely moving)
		# =====================================
		# Fingers digging in, desperate grip. You feel in control.
		# Slight progress through grip phase adds tiny acceleration for realism
		var grip_progress = cling_time / grip_duration
		return lerp(grip_speed * 0.2, grip_speed, grip_progress)
		
	elif cling_time < grip_duration + fatigue_duration:
		# =====================================
		# PHASE 2: FATIGUE (accelerating slide)
		# =====================================
		# Grip weakening! The "woah woah woah" phase.
		# Quadratic acceleration creates exponential-feel urgency.
		var fatigue_progress = (cling_time - grip_duration) / fatigue_duration
		# Quadratic curve: slow start, rapidly accelerating
		var curve = fatigue_progress * fatigue_progress
		return lerp(initial_speed, max_speed, curve)
		
	else:
		# =====================================
		# PHASE 3: SLIP (terminal velocity)
		# =====================================
		# You're toast. Maximum slide speed. Act NOW or fall.
		return max_speed

