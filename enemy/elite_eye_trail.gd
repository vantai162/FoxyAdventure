class_name EliteEyeTrail
extends Node2D
## Red glowing eye trail system for elite enemies
## GPU-accelerated particle stream (world-space emission creates natural trail)
## Unified visual language: "RED EYE = DANGER"

@export var eye_color: Color = Color(1.0, 0.0, 0.0, 1.0)  ## Pure red
@export var trail_brightness: float = 4.0  ## HDR glow multiplier
@export var trail_lifetime: float = 0.4  ## How long trail persists (seconds)
@export var emission_rate: float = 120.0  ## Particles per second (higher = denser trail)

var eye_dot: Sprite2D
var particles: GPUParticles2D
var glow_time: float = 0.0

func _ready():
	# Create small glowing eye core
	eye_dot = Sprite2D.new()
	eye_dot.texture = _create_eye_texture()
	eye_dot.position = Vector2.ZERO
	eye_dot.modulate = eye_color * trail_brightness
	eye_dot.z_index = 100
	eye_dot.scale = Vector2(0.6, 0.6)
	add_child(eye_dot)
	
	# GPU particle system - world space emission creates trail automatically
	particles = GPUParticles2D.new()
	particles.position = Vector2.ZERO
	particles.emitting = true
	particles.amount = int(emission_rate * trail_lifetime)  # Enough for full trail
	particles.lifetime = trail_lifetime
	particles.preprocess = 0.0
	particles.speed_scale = 1.0
	particles.explosiveness = 0.0  # Continuous stream
	particles.randomness = 0.02  # Minimal spread
	particles.fixed_fps = 60
	particles.local_coords = false  # CRITICAL: World space for trail effect
	particles.z_index = 99
	
	# ParticleProcessMaterial (GPU-accelerated physics)
	var material = ParticleProcessMaterial.new()
	
	# Emission: point source at eye position
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	
	# Particles start stationary (trail created by enemy movement in world space)
	material.direction = Vector3(0, 0, 0)
	material.spread = 5.0  # Tiny spread for tight beam
	material.initial_velocity_min = 0.0
	material.initial_velocity_max = 2.0  # Barely move
	
	# Slight upward drift (ethereal float)
	material.gravity = Vector3(0, -10, 0)
	
	# Damping: particles slow down (stay in place as enemy moves past)
	material.linear_accel_min = -5.0
	material.linear_accel_max = -2.0
	
	# Scale: start small, stay small
	material.scale_min = 0.8
	material.scale_max = 1.2
	
	# Color with fadeout
	material.color = eye_color * trail_brightness
	material.color_ramp = _create_color_ramp()
	
	particles.process_material = material
	
	# Particle texture: soft glowing dot
	particles.texture = _create_particle_texture()
	
	add_child(particles)

func _create_eye_texture() -> ImageTexture:
	# 7×7 glowing core with sharp center
	var image = Image.create(7, 7, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	
	# Bright center
	image.set_pixel(3, 3, Color(1, 1, 1, 1.0))
	
	# Inner ring
	for offset in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
		image.set_pixel(3 + offset.x, 3 + offset.y, Color(1, 0.95, 0.95, 0.9))
	
	# Mid ring
	for offset in [Vector2i(-2,0), Vector2i(2,0), Vector2i(0,-2), Vector2i(0,2),
				   Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1)]:
		image.set_pixel(3 + offset.x, 3 + offset.y, Color(1, 0.9, 0.9, 0.7))
	
	# Outer glow
	for offset in [Vector2i(-3,0), Vector2i(3,0), Vector2i(0,-3), Vector2i(0,3)]:
		image.set_pixel(3 + offset.x, 3 + offset.y, Color(1, 0.85, 0.85, 0.4))
	
	return ImageTexture.create_from_image(image)

func _create_particle_texture() -> ImageTexture:
	# 8×8 soft glow (GPU blends these together for trail effect)
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	
	# Radial gradient glow
	var center = Vector2(4, 4)
	for y in range(8):
		for x in range(8):
			var dist = center.distance_to(Vector2(x, y))
			var intensity = clamp(1.0 - (dist / 4.0), 0.0, 1.0)
			intensity = pow(intensity, 1.5)  # Sharper falloff
			image.set_pixel(x, y, Color(1, 1, 1, intensity))
	
	return ImageTexture.create_from_image(image)

func _create_color_ramp() -> Gradient:
	# Sharp fade: bright → transparent
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1.0))  # Start full brightness
	gradient.set_color(0.7, Color(1, 1, 1, 0.6))  # Hold visibility
	gradient.set_color(1, Color(1, 1, 1, 0.0))  # Fade to transparent
	return gradient

func _process(delta: float):
	# Pulse the eye core
	glow_time += delta * 5.0
	var pulse = (sin(glow_time) + 1.0) / 2.0
	var brightness = lerp(3.0, trail_brightness * 1.5, pulse)
	eye_dot.modulate = eye_color * brightness
