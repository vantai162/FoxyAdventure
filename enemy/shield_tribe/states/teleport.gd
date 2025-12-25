extends EnemyState
## Elite Warden Teleport State
## Shadow-step mechanic: Fade out -> Reposition -> Fade in
## NO line-of-sight check - can teleport through walls (horrifying!)
## Alternates between frontal blocking and rear flanking

@export var teleport_duration: float = 1.1  ## Total animation time (extended for smoothness)
@export var pre_fade_time: float = 0.15  ## Warning shimmer before fade (reduced)
@export var fade_out_time: float = 0.35  ## Dissolve time (extended, eased)
@export var travel_time: float = 0.1  ## Invisible repositioning
@export var fade_in_time: float = 0.5  ## Materialize time (extended, eased)

## Teleport phases
enum Phase { PRE_FADE, FADE_OUT, TRAVEL, FADE_IN, COMPLETE }
var current_phase: Phase = Phase.PRE_FADE
var phase_timer: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var target_direction: int = 1  ## Which way to face after teleport

func _enter() -> void:
	current_phase = Phase.PRE_FADE
	phase_timer = 0.0
	
	# Stop all movement during teleport
	obj.velocity = Vector2.ZERO
	
	# Calculate destination (block or flank based on alternating pattern)
	target_position = obj.get_teleport_destination()
	
	# Validate destination (if ground check failed, fallback to player side)
	if target_position == Vector2.ZERO:
		# Fallback: teleport directly beside player
		if obj.found_player:
			var side = 1 if obj.teleport_to_front else -1
			target_position = obj.found_player.global_position + Vector2(side * 48, 0)
		else:
			# Emergency: stay in place and return to idle
			change_state(fsm.states.idle)
			return
	
	# Determine which direction to face after teleport (toward player)
	if obj.found_player:
		target_direction = 1 if obj.found_player.global_position.x > target_position.x else -1
	
	# Start pre-fade warning
	obj.change_animation("idle")  ## Neutral pose during teleport
	obj.hide_shield()  ## Shield down during teleport
	_spawn_pre_fade_particles()

func _update(delta: float) -> void:
	phase_timer += delta
	
	# Safety check: If player died/disappeared during teleport, abort
	if not is_instance_valid(obj.found_player):
		obj.modulate.a = 1.0  # Restore visibility
		change_state(fsm.states.idle)
		return
	
	match current_phase:
		Phase.PRE_FADE:
			if phase_timer >= pre_fade_time:
				_transition_to_fade_out()
		
		Phase.FADE_OUT:
			_update_fade_out_alpha()
			if phase_timer >= pre_fade_time + fade_out_time:
				_transition_to_travel()
		
		Phase.TRAVEL:
			if phase_timer >= pre_fade_time + fade_out_time + travel_time:
				_transition_to_fade_in()
		
		Phase.FADE_IN:
			_update_fade_in_alpha()
			if phase_timer >= teleport_duration:
				_transition_to_complete()

func _transition_to_fade_out() -> void:
	current_phase = Phase.FADE_OUT
	# Start fading out sprite
	obj.modulate.a = 1.0

func _update_fade_out_alpha() -> void:
	## Fade sprite alpha from 1.0 to 0.0 over fade_out_time with ease-in curve
	var fade_progress = (phase_timer - pre_fade_time) / fade_out_time
	fade_progress = clamp(fade_progress, 0.0, 1.0)
	
	# Ease-in cubic: slow start, accelerating dissolve (more organic)
	var eased = fade_progress * fade_progress * fade_progress
	obj.modulate.a = 1.0 - eased

func _transition_to_travel() -> void:
	current_phase = Phase.TRAVEL
	
	# Instant repositioning (invisible)
	obj.global_position = target_position
	obj.change_direction(target_direction)
	obj.modulate.a = 0.0
	
	# Spawn arrival particles
	_spawn_arrival_particles()
	AudioManager.play_sound("claw_attack",12.0)

func _transition_to_fade_in() -> void:
	current_phase = Phase.FADE_IN
	# Start fading in sprite at new position (camera shake delayed for impact)

func _update_fade_in_alpha() -> void:
	## Fade sprite alpha from 0.0 to 1.0 over fade_in_time with ease-out curve
	var fade_start_time = pre_fade_time + fade_out_time + travel_time
	var fade_progress = (phase_timer - fade_start_time) / fade_in_time
	fade_progress = clamp(fade_progress, 0.0, 1.0)
	
	# Ease-out cubic: fast start, decelerating materialize (snappy arrival)
	var eased = 1.0 - pow(1.0 - fade_progress, 3.0)
	obj.modulate.a = eased
	
	# Camera shake at 20% materialization (early impact, feels reactive)
	if fade_progress >= 0.2 and fade_progress < 0.25:
		if not has_meta("shake_triggered"):
			_shake_camera(2.5)
			set_meta("shake_triggered", true)

func _transition_to_complete() -> void:
	current_phase = Phase.COMPLETE
	obj.modulate.a = 1.0  ## Ensure fully visible
	
	# Mark teleport used (updates cooldown and flips pattern)
	obj.mark_teleport_used()
	
	# Transition to Defend state with ambush bonus (faster first attack)
	if fsm.states.has("defend"):
		change_state(fsm.states.defend)
	else:
		change_state(fsm.states.idle)

func _exit() -> void:
	# Ensure sprite is fully visible when leaving state
	obj.modulate.a = 1.0
	# Clear shake trigger meta for next teleport
	if has_meta("shake_triggered"):
		remove_meta("shake_triggered")

## VFX spawning - Optimized GPU particles with auto-cleanup
func _spawn_pre_fade_particles() -> void:
	## Pre-fade warning: Purple shimmer sparks (elite signature color)
	var particles = GPUParticles2D.new()
	particles.name = "PreFadeShimmer"
	particles.position = Vector2.ZERO  # Relative to obj
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12  # Low count for performance
	particles.lifetime = 0.3
	particles.explosiveness = 0.8  # Burst effect
	particles.z_index = ZLayers.EFFECT_FRONT  # Particles above enemies
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 16.0  # Small radius around body
	mat.direction = Vector3(0, -1, 0)  # Upward
	mat.spread = 180.0  # All directions
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0, -50, 0)  # Rise then fall
	mat.damping_min = 8.0
	mat.damping_max = 12.0
	mat.scale_min = 1.5
	mat.scale_max = 2.5
	
	# Fade curve
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 1))
	alpha_curve.add_point(Vector2(0.5, 0.8))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	# Purple/magenta gradient (elite color)
	var grad = Gradient.new()
	grad.add_point(0.0, Color(0.9, 0.5, 1.0, 1.0))  # Bright magenta
	grad.add_point(0.5, Color(0.6, 0.3, 0.8, 0.8))  # Purple
	grad.add_point(1.0, Color.TRANSPARENT)
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = grad
	mat.color_ramp = gradient_texture
	
	particles.process_material = mat
	obj.add_child(particles)
	
	# Auto-cleanup after emission
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(
		func(): if is_instance_valid(particles): particles.queue_free()
	)

func _spawn_arrival_particles() -> void:
	## Arrival impact: Ground ripple + shadow smoke burst
	var particles = GPUParticles2D.new()
	particles.name = "ArrivalImpact"
	particles.position = Vector2(0, 12)  # At feet level
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 16  # Medium count
	particles.lifetime = 0.5
	particles.explosiveness = 0.9  # Strong burst
	particles.z_index = ZLayers.EFFECT_FRONT  # Particles above enemies
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0, 0, 1)  # Horizontal ring
	mat.emission_ring_height = 2.0
	mat.emission_ring_radius = 8.0
	mat.emission_ring_inner_radius = 4.0
	mat.direction = Vector3(1, 0, 0)  # Radial outward
	mat.spread = 180.0  # Full circle spread
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 30, 0)  # Slight fall
	mat.damping_min = 15.0  # Quick dissipation
	mat.damping_max = 20.0
	mat.scale_min = 2.0
	mat.scale_max = 3.5
	
	# Fade curve (quick flash then fade)
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 1))
	alpha_curve.add_point(Vector2(0.3, 0.7))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	# Dark purple to smoke gray (shadow dissipation)
	var grad = Gradient.new()
	grad.add_point(0.0, Color(0.5, 0.2, 0.6, 1.0))  # Dark purple
	grad.add_point(0.4, Color(0.3, 0.3, 0.4, 0.6))  # Purple-gray
	grad.add_point(0.8, Color(0.2, 0.2, 0.25, 0.3))  # Smoke gray
	grad.add_point(1.0, Color.TRANSPARENT)
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = grad
	mat.color_ramp = gradient_texture
	
	particles.process_material = mat
	obj.add_child(particles)
	
	# Auto-cleanup
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(
		func(): if is_instance_valid(particles): particles.queue_free()
	)


func _shake_camera(strength: float) -> void:
	## Shake the active camera - works with player camera OR arena cameras
	# Try viewport camera first
	var viewport = obj.get_viewport()
	if not viewport:
		return
	
	var camera = viewport.get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(strength)
	elif obj.found_player and obj.found_player.has_node("Camera2D"):
		# Fallback to player camera
		var player_cam = obj.found_player.get_node("Camera2D")
		if player_cam.has_method("shake"):
			player_cam.shake(strength)
