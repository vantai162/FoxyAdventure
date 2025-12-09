extends Node2D
class_name CampFire

## Campfire - Warm light source with GPU particles and flickering glow
## Essential for cave atmosphere - provides safety and light
## NOW FULLY GPU-ACCELERATED - zero CPU particle overhead
##
## SETUP: Scene includes PointLight2D "FireLight" and 3 GPUParticles2D nodes.
## Configure particle materials and light properties in editor.
## Script only handles flicker Tween and enable/disable logic.

@export_group("Flicker Settings")
@export var flicker_enabled: bool = true
@export var flicker_speed: float = 6.0
@export var flicker_intensity: float = 0.25  ## 0.0-1.0, how much energy varies

@export_group("Interaction")
@export var warmth_zone_enabled: bool = false  ## Safe zone for player (future feature)
@export var warmth_radius: float = 60.0

## Scene node references - all configured in editor
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fire_light: PointLight2D = $FireLight
@onready var spark_particles: GPUParticles2D = $SparkParticles
@onready var smoke_particles: GPUParticles2D = $SmokeParticles
@onready var ember_particles: GPUParticles2D = $EmberParticles

var _base_energy: float = 1.0  ## Captured from light at start
var _base_color: Color = Color.WHITE
var _flicker_tween: Tween

func _ready() -> void:
	# Play fire animation
	if animated_sprite:
		animated_sprite.play("default")
	
	# Configure light
	if fire_light:
		_base_energy = fire_light.energy
		_base_color = fire_light.color
		if fire_light.texture == null:
			_setup_light_texture()
	
	# Setup GPU particles
	_setup_particles()
	
	# Start flicker animation
	if flicker_enabled:
		_start_flicker()

func _setup_light_texture() -> void:
	## Smooth gradient for light glow
	var gradient = GradientTexture2D.new()
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(0.5, 0.0)
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color.TRANSPARENT)
	gradient.gradient = grad
	gradient.width = 256
	gradient.height = 256
	fire_light.texture = gradient

func _setup_particles() -> void:
	## Configure GPU particle materials
	
	# SPARKS - small, fast, upward
	if spark_particles:
		_setup_spark_material()
	
	# SMOKE - large, slow, expanding
	if smoke_particles:
		_setup_smoke_material()
	
	# EMBERS - hovering, pulsing glow
	if ember_particles:
		_setup_ember_material()

func _setup_spark_material() -> void:
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(12, 4, 0)  # Spread across fire
	mat.direction = Vector3(0, -1, 0)  # Upward (Y- in Godot)
	mat.spread = 25.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 50.0
	mat.gravity = Vector3(0, 10, 0)  # Gravity pulls down (Y+ is down in Godot!)
	mat.damping_min = 5.0  # Air resistance
	mat.damping_max = 10.0
	mat.scale_min = 1.5
	mat.scale_max = 2.5
	
	# Fade out curve
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 1))
	alpha_curve.add_point(Vector2(0.7, 0.8))
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
	
	spark_particles.process_material = mat
	
	add_child(spark_particles)

func _setup_smoke_material() -> void:
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(6, 2, 0)
	mat.direction = Vector3(0, -1, 0)  # Upward
	mat.spread = 15.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, -10, 0)  # Slow rise
	mat.scale_min = 4.0
	mat.scale_max = 7.0
	
	# Expand and fade
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 0.4))
	alpha_curve.add_point(Vector2(0.3, 0.3))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	# Grow curve
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1))
	scale_curve.add_point(Vector2(1, 2.5))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex
	
	smoke_particles.process_material = mat
	
	# Create smoke texture (soft gray circle)
	var smoke_tex = GradientTexture2D.new()
	smoke_tex.width = 16
	smoke_tex.height = 16
	smoke_tex.fill = GradientTexture2D.FILL_RADIAL
	smoke_tex.fill_from = Vector2(0.5, 0.5)
	smoke_tex.fill_to = Vector2(0.5, 0.0)
	var smoke_grad = Gradient.new()
	smoke_grad.set_color(0, Color(0.3, 0.3, 0.3, 0.4))
	smoke_grad.set_color(1, Color(0.2, 0.2, 0.2, 0))
	smoke_tex.gradient = smoke_grad
	smoke_particles.texture = smoke_tex

func _setup_ember_material() -> void:
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(15, 10, 0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, -8, 0)  # Gentle float
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	
	# Pulsing alpha
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 0))
	alpha_curve.add_point(Vector2(0.2, 0.8))
	alpha_curve.add_point(Vector2(0.5, 1))
	alpha_curve.add_point(Vector2(0.8, 0.7))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	ember_particles.process_material = mat
	
	# Create ember texture (orange glow)
	var ember_tex = GradientTexture2D.new()
	ember_tex.width = 8
	ember_tex.height = 8
	ember_tex.fill = GradientTexture2D.FILL_RADIAL
	ember_tex.fill_from = Vector2(0.5, 0.5)
	ember_tex.fill_to = Vector2(0.5, 0.0)
	var ember_grad = Gradient.new()
	ember_grad.set_color(0, Color(1, 0.4, 0.1, 0.8))
	ember_grad.set_color(1, Color(1, 0.3, 0.0, 0))
	ember_tex.gradient = ember_grad
	ember_particles.texture = ember_tex

func _start_flicker() -> void:
	if not fire_light:
		return
	
	if _flicker_tween:
		_flicker_tween.kill()
	
	_flicker_tween = create_tween().set_loops()
	var duration = 1.0 / max(0.1, flicker_speed)
	var energy_high = _base_energy + flicker_intensity
	var energy_low = _base_energy - flicker_intensity
	
	# Multi-phase flicker for organic feel
	_flicker_tween.tween_property(fire_light, "energy", energy_high, duration * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flicker_tween.tween_property(fire_light, "energy", energy_low, duration * 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flicker_tween.tween_property(fire_light, "energy", _base_energy, duration * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Extinguish the fire (for gameplay mechanics)
func extinguish() -> void:
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.visible = false
	
	if fire_light:
		var tween = create_tween()
		tween.tween_property(fire_light, "energy", 0.0, 0.5)
	
	if _flicker_tween:
		_flicker_tween.kill()
	
	# Disable GPU particles
	if spark_particles:
		spark_particles.emitting = false
	if smoke_particles:
		smoke_particles.emitting = false
	if ember_particles:
		ember_particles.emitting = false

## Re-ignite the fire
func ignite() -> void:
	if animated_sprite:
		animated_sprite.visible = true
		animated_sprite.play("default")
	
	if fire_light:
		var tween = create_tween()
		tween.tween_property(fire_light, "energy", _base_energy, 0.3)
	
	# Re-enable GPU particles
	if spark_particles:
		spark_particles.emitting = true
	if smoke_particles:
		smoke_particles.emitting = true
	if ember_particles:
		ember_particles.emitting = true
	
	# Restart flicker
	if flicker_enabled:
		_start_flicker()
