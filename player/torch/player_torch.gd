extends Node2D
## Torch that illuminates dark areas - follows player direction
##
## Scene structure (finalized):
##   PlayerTorch (Node2D) - this script
##   ├── TorchSprite (AnimatedSprite2D) - animated torch with flame
##   ├── TorchLight (PointLight2D) - the light glow
##   └── TorchSparks (GPUParticles2D) - spark particles

@export_group("Behavior")
@export var flicker_enabled: bool = true
@export var flicker_speed: float = 8.0  ## Flickers per second
@export var flicker_intensity: float = 0.15  ## Energy variance

@export_group("State")
@export var is_lit: bool = false  ## Starts OFF, auto-lights in dark levels

## Child node references
@onready var torch_sprite: AnimatedSprite2D = $TorchSprite
@onready var torch_light: PointLight2D = $TorchLight
@onready var torch_sparks: GPUParticles2D = $TorchSparks

var _flicker_tween: Tween
var _base_energy: float


func _ready() -> void:
	_base_energy = torch_light.energy
	
	# Auto-detect darkness in level
	if not is_lit:
		_auto_detect_darkness()
	
	# Setup particles if not configured
	if torch_sparks.process_material == null:
		_setup_spark_material()
	
	_apply_lit_state()


func _auto_detect_darkness() -> void:
	## Auto-light torch if level has darkness (DarknessModulate or CanvasModulate)
	var scene_root = get_tree().current_scene
	if not scene_root:
		return
	
	var darkness = scene_root.get_node_or_null("DarknessModulate")
	if not darkness:
		darkness = scene_root.get_node_or_null("CanvasModulate")
	
	if darkness and darkness is CanvasModulate:
		is_lit = true


func _apply_lit_state() -> void:
	## Apply current is_lit state to all child nodes
	torch_light.enabled = is_lit
	torch_light.energy = _base_energy if is_lit else 0.0
	
	torch_sprite.visible = is_lit
	if is_lit:
		torch_sprite.play("default")
	
	torch_sparks.emitting = is_lit
	
	if is_lit and flicker_enabled:
		_start_flicker()


func _start_flicker() -> void:
	if _flicker_tween:
		_flicker_tween.kill()
	
	_flicker_tween = create_tween().set_loops()
	var duration = 1.0 / max(0.1, flicker_speed)
	var energy_high = _base_energy + flicker_intensity
	var energy_low = _base_energy - flicker_intensity
	
	# Organic multi-phase flicker
	_flicker_tween.tween_property(torch_light, "energy", energy_high, duration * 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flicker_tween.tween_property(torch_light, "energy", energy_low, duration * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flicker_tween.tween_property(torch_light, "energy", _base_energy, duration * 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func light_torch() -> void:
	## Turn on the torch with fade-in effect
	is_lit = true
	
	torch_light.enabled = true
	torch_light.energy = 0
	var tween = create_tween()
	tween.tween_property(torch_light, "energy", _base_energy, 0.3)
	
	torch_sprite.visible = true
	torch_sprite.play("default")
	
	torch_sparks.emitting = true
	
	if flicker_enabled:
		_start_flicker()


func extinguish_torch() -> void:
	## Turn off the torch with fade-out effect
	is_lit = false
	
	torch_sparks.emitting = false
	
	if _flicker_tween:
		_flicker_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(torch_light, "energy", 0.0, 0.2)
	await tween.finished
	torch_light.enabled = false
	torch_sprite.visible = false


func _setup_spark_material() -> void:
	## Configure spark particles
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 3.0
	mat.direction = Vector3(0, -1, 0)  # Upward
	mat.spread = 40.0
	mat.initial_velocity_min = 25.0
	mat.initial_velocity_max = 35.0
	mat.gravity = Vector3(0, 15, 0)  # Fall down
	mat.damping_min = 8.0
	mat.damping_max = 12.0
	mat.scale_min = 1.5
	mat.scale_max = 2.5
	
	# Fade curve
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 1))
	alpha_curve.add_point(Vector2(0.6, 0.7))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	# Color gradient
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.8, 0.5))
	grad.add_point(0.7, Color(1.0, 0.5, 0.2, 0.5))
	grad.add_point(1.0, Color.TRANSPARENT)
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = grad
	mat.color_ramp = gradient_texture
	
	torch_sparks.process_material = mat
