extends PointLight2D
class_name PlayerTorch

## Torch light that follows the player
## NOW GPU-ACCELERATED - zero CPU particle overhead
## Flickers via Tween and uses GPUParticles2D for sparks
## Casts shadows when walls have LightOccluder2D

@export_group("Torch Settings")
@export var base_energy: float = 1.0
@export var base_radius: float = 200.0
@export var flicker_enabled: bool = true
@export var flicker_speed: float = 8.0
@export var flicker_intensity: float = 0.15

@export_group("Shadow Settings")
@export var cast_shadows: bool = true  ## Enable shadow casting (walls block light)

@export_group("Spark Particles")
@export var emit_sparks: bool = true
@export var spark_count: int = 8  ## Max particles active
@export var spark_lifetime: float = 0.6

@export_group("State")
@export var is_lit: bool = true

var _spark_particles: GPUParticles2D
var _flicker_tween: Tween

func _ready() -> void:
	texture_scale = base_radius / 512.0
	energy = base_energy
	enabled = is_lit
	shadow_enabled = cast_shadows
	
	# Create radial gradient texture if none exists
	if texture == null:
		_create_light_texture()
	
	# Setup GPU particles
	if emit_sparks:
		_setup_spark_particles()
	
	# Start flicker animation
	if flicker_enabled and is_lit:
		_start_flicker()

func _create_light_texture() -> void:
	## Smooth gradient for light glow - particles are the sharp bits!
	var gradient = GradientTexture2D.new()
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(0.5, 0.0)
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color.TRANSPARENT)
	gradient.gradient = grad
	gradient.width = 512
	gradient.height = 512
	texture = gradient

func _setup_spark_particles() -> void:
	_spark_particles = GPUParticles2D.new()
	_spark_particles.name = "TorchSparks"
	_spark_particles.position = Vector2(0, -5)  # Slightly above center
	_spark_particles.amount = spark_count
	_spark_particles.lifetime = spark_lifetime
	_spark_particles.randomness = 0.4
	_spark_particles.emitting = is_lit
	
	# Configure particle material - welding spark style
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 3.0
	mat.direction = Vector3(0, -1, 0)  # Upward (Y- in Godot)
	mat.spread = 40.0
	mat.initial_velocity_min = 25.0
	mat.initial_velocity_max = 35.0
	mat.gravity = Vector3(0, 15, 0)  # Gravity pulls down (Y+ is down!)
	mat.damping_min = 8.0  # Slow down quickly
	mat.damping_max = 12.0
	mat.scale_min = 1.5
	mat.scale_max = 2.5
	
	# Fade out curve
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 1))
	alpha_curve.add_point(Vector2(0.6, 0.7))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	# Scale shrink
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1))
	scale_curve.add_point(Vector2(1, 0.4))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex
	
	# Use GradientTexture1D for color_ramp (like whirlpool)
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.8, 0.5))
	grad.add_point(0.7, Color(1.0, 0.5, 0.2, 0.5))
	grad.add_point(1.0, Color.TRANSPARENT)
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = grad
	mat.color_ramp = gradient_texture
	
	_spark_particles.process_material = mat
	
	add_child(_spark_particles)

func _start_flicker() -> void:
	if _flicker_tween:
		_flicker_tween.kill()
	
	_flicker_tween = create_tween().set_loops()
	var duration = 1.0 / max(0.1, flicker_speed)
	var energy_high = base_energy + flicker_intensity
	var energy_low = base_energy - flicker_intensity
	
	# Organic multi-phase flicker
	_flicker_tween.tween_property(self, "energy", energy_high, duration * 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flicker_tween.tween_property(self, "energy", energy_low, duration * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flicker_tween.tween_property(self, "energy", base_energy, duration * 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func light_torch() -> void:
	is_lit = true
	enabled = true
	
	if _spark_particles:
		_spark_particles.emitting = true
	
	# Fade in effect
	var tween = create_tween()
	energy = 0
	tween.tween_property(self, "energy", base_energy, 0.3)
	
	if flicker_enabled:
		_start_flicker()

func extinguish_torch() -> void:
	is_lit = false
	
	if _spark_particles:
		_spark_particles.emitting = false
	
	if _flicker_tween:
		_flicker_tween.kill()
	
	# Fade out effect
	var tween = create_tween()
	tween.tween_property(self, "energy", 0.0, 0.2)
	await tween.finished
	enabled = false

func set_radius(new_radius: float) -> void:
	base_radius = new_radius
	texture_scale = base_radius / 512.0
