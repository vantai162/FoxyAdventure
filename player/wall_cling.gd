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
##
## VISUAL FEEDBACK (Kojima-approved):
## - Wall scrape particles scale with slide intensity
## - Claw sparks appear during slip phase (the "oh shit" indicator)
## - All particles fly AWAY from wall for physical correctness
## ============================================================================

## Particle effect scenes
const WALL_SCRAPE_SCENE: PackedScene = preload("res://assets/effects/wall_scrape.tscn")
const CLAW_SPARKS_SCENE: PackedScene = preload("res://assets/effects/claw_sparks.tscn")

## Active particle instances
var wall_scrape_particles: GPUParticles2D = null
var claw_sparks_particles: GPUParticles2D = null

## Spark burst timing (staccato bursts during slip phase)
var spark_timer: float = 0.0
const SPARK_INTERVAL: float = 0.12  ## Time between spark bursts

## Time spent clinging since last grip reset
var cling_time: float = 0.0

## Cache the wall direction for consistent checking
var wall_direction: int = 0  ## 1 = wall on right, -1 = wall on left

## Cache the wall normal for particle direction
var wall_normal: Vector2 = Vector2.ZERO

func _enter() -> void:
	obj.change_animation("jump")
	obj.jump_count = 0
	obj.dashed_on_air = false
	
	# Reset grip timer on entry (fresh cling = fresh grip)
	cling_time = 0.0
	spark_timer = 0.0
	
	# Determine which side the wall is on and cache wall normal
	wall_direction = _detect_wall_direction()
	wall_normal = _get_wall_normal()
	
	# Spawn particle effects
	_spawn_particles()

func _exit() -> void:
	# Clean up particles
	_cleanup_particles()
	
	# Clean up state
	wall_direction = 0
	wall_normal = Vector2.ZERO

func _update(delta: float):
	obj.current_oxygen = min(obj.max_oxygen, obj.current_oxygen + obj.oxygen_increase_rate * delta)
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
	var current_phase: int = _get_current_phase()
	
	# Only apply slide if not moving up (ascending from wall jump)
	if obj.velocity.y >= 0:
		obj.velocity.y = slide_velocity
	
	# Prevent horizontal drift - lock to wall
	# Small push toward wall to maintain contact
	obj.velocity.x = obj.direction * 5.0
	
	# ========================================
	# VISUAL: Update particle effects
	# ========================================
	_update_particles(delta, current_phase, slide_velocity)

## ============================================================================
## PARTICLE SYSTEM: Spawn, Update, Cleanup
## ============================================================================

func _spawn_particles() -> void:
	## Calculate initial contact position FIRST
	var contact_pos = _get_wall_contact_position()
	
	## Create wall scrape particles (continuous debris)
	if WALL_SCRAPE_SCENE:
		wall_scrape_particles = WALL_SCRAPE_SCENE.instantiate()
		
		# Set position BEFORE adding to tree and emitting
		wall_scrape_particles.global_position = contact_pos
		
		# z_index is baked into .tscn (ZLayers.EFFECT_FRONT = 25)
		
		# Set initial direction based on wall normal
		var mat = wall_scrape_particles.process_material as ParticleProcessMaterial
		if mat:
			mat.direction = Vector3(wall_normal.x, 0.3, 0)
		
		# Add to scene tree using current_scene (standard pattern)
		obj.get_tree().current_scene.add_child(wall_scrape_particles)
		
		# NOW emit (after position is set)
		wall_scrape_particles.emitting = true
	
	## Create claw sparks (burst effect, starts disabled)
	if CLAW_SPARKS_SCENE:
		claw_sparks_particles = CLAW_SPARKS_SCENE.instantiate()
		
		# Set position BEFORE adding to tree
		claw_sparks_particles.global_position = contact_pos
		
		# z_index is baked into .tscn (ZLayers.EFFECT_FRONT = 25)
		
		# Set initial direction
		var mat = claw_sparks_particles.process_material as ParticleProcessMaterial
		if mat:
			mat.direction = Vector3(wall_normal.x, -0.5, 0)
		
		# Add to scene tree
		obj.get_tree().current_scene.add_child(claw_sparks_particles)
		
		# Sparks don't emit until slip phase
		claw_sparks_particles.emitting = false

func _cleanup_particles() -> void:
	## Remove and free particle instances - let them fade naturally
	if wall_scrape_particles and is_instance_valid(wall_scrape_particles):
		wall_scrape_particles.emitting = false
		var scrape = wall_scrape_particles
		wall_scrape_particles = null
		# Use timer callback for cleanup (no await, prevents state issues)
		if scrape.get_tree():
			scrape.get_tree().create_timer(scrape.lifetime + 0.1).timeout.connect(
				func(): 
					if is_instance_valid(scrape): 
						scrape.queue_free()
			)
	
	if claw_sparks_particles and is_instance_valid(claw_sparks_particles):
		claw_sparks_particles.emitting = false
		var sparks = claw_sparks_particles
		claw_sparks_particles = null
		if sparks.get_tree():
			sparks.get_tree().create_timer(sparks.lifetime + 0.1).timeout.connect(
				func(): 
					if is_instance_valid(sparks): 
						sparks.queue_free()
			)

func _update_particles(delta: float, phase: int, slide_velocity: float) -> void:
	## Position particles at wall contact point
	var contact_pos = _get_wall_contact_position()
	
	## Update wall scrape particles
	if wall_scrape_particles and is_instance_valid(wall_scrape_particles):
		wall_scrape_particles.global_position = contact_pos
		
		# Flip particle direction based on wall normal (particles fly away from wall)
		var mat = wall_scrape_particles.process_material as ParticleProcessMaterial
		if mat:
			# Direction: away from wall (wall_normal points away from wall)
			mat.direction = Vector3(wall_normal.x, 0.3, 0)
		
		# Scale intensity based on phase
		match phase:
			0:  # GRIP - minimal particles
				wall_scrape_particles.amount = 2
				wall_scrape_particles.speed_scale = 0.5
			1:  # FATIGUE - increasing particles
				var fatigue_progress = _get_fatigue_progress()
				wall_scrape_particles.amount = int(lerp(3.0, 8.0, fatigue_progress))
				wall_scrape_particles.speed_scale = lerp(0.7, 1.2, fatigue_progress)
			2:  # SLIP - maximum particles
				wall_scrape_particles.amount = 10
				wall_scrape_particles.speed_scale = 1.5
	
	## Update claw sparks (slip phase only)
	if claw_sparks_particles and is_instance_valid(claw_sparks_particles):
		claw_sparks_particles.global_position = contact_pos
		
		# Flip spark direction
		var mat = claw_sparks_particles.process_material as ParticleProcessMaterial
		if mat:
			mat.direction = Vector3(wall_normal.x, -0.5, 0)
		
		# Sparks only during slip phase, in staccato bursts
		if phase == 2:  # SLIP
			spark_timer += delta
			if spark_timer >= SPARK_INTERVAL:
				spark_timer = 0.0
				# Trigger a burst
				claw_sparks_particles.emitting = false
				claw_sparks_particles.emitting = true
		else:
			claw_sparks_particles.emitting = false

func _get_wall_contact_position() -> Vector2:
	## Calculate where the player's claws contact the wall
	## Slightly offset from player center toward the wall
	var offset_x = obj.direction * 12.0  # 12px toward wall (player is 32px wide)
	var offset_y = -8.0  # Slightly above center (where hands would be)
	return obj.global_position + Vector2(offset_x, offset_y)

func _get_wall_normal() -> Vector2:
	## Get the wall's surface normal (points away from wall)
	for i in obj.get_slide_collision_count():
		var collision = obj.get_slide_collision(i)
		var normal = collision.get_normal()
		if abs(normal.x) > 0.5:
			return Vector2(normal.x, normal.y)
	return Vector2(-obj.direction, 0)  # Fallback

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
## HELPER: Get current cling phase (0 = grip, 1 = fatigue, 2 = slip)
## ============================================================================
func _get_current_phase() -> int:
	var grip_duration = obj.wall_grip_phase_duration
	var fatigue_duration = obj.wall_fatigue_phase_duration
	
	if cling_time < grip_duration:
		return 0  # GRIP
	elif cling_time < grip_duration + fatigue_duration:
		return 1  # FATIGUE
	else:
		return 2  # SLIP

## ============================================================================
## HELPER: Get fatigue phase progress (0.0 to 1.0)
## ============================================================================
func _get_fatigue_progress() -> float:
	var grip_duration = obj.wall_grip_phase_duration
	var fatigue_duration = obj.wall_fatigue_phase_duration
	
	if cling_time < grip_duration:
		return 0.0
	elif cling_time < grip_duration + fatigue_duration:
		return (cling_time - grip_duration) / fatigue_duration
	else:
		return 1.0

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
