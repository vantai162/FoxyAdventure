extends Node2D
## Torch that illuminates dark areas - follows player direction
## 
## DESIGN PHILOSOPHY:
## The torch doesn't just "appear" - it IGNITES when entering darkness.
## A brief delay and fade-in makes this feel intentional and magical,
## like the torch responds to the environment rather than being a static prop.
##
## Scene structure:
##   PlayerTorch (Node2D) - this script
##   ├── TorchSprite (AnimatedSprite2D) - animated torch with flame (7×24 px)
##   ├── TorchLight (PointLight2D) - the warm glow
##   └── TorchSparks (GPUParticles2D) - spark particles

@export_group("Behavior")
@export var flicker_enabled: bool = true
@export var flicker_speed: float = 8.0  ## Flickers per second
@export var flicker_intensity: float = 0.15  ## Energy variance (±)
## Enable debug logging
@export var debug_logging: bool = false

@export_group("Ignition Effect")
## Delay before torch ignites (feels like responding to darkness)
## NOTE: Keep this shorter than the transition wipe_in duration (0.15s)
## so torch is lit BEFORE the reveal completes
@export var ignition_delay: float = 0.08
## How long the flame fades in
@export var ignition_duration: float = 0.25
## How long to fade out when extinguishing
@export var extinguish_duration: float = 0.15

@export_group("State")
@export var is_lit: bool = false  ## Current torch state

## Child node references
@onready var torch_sprite: AnimatedSprite2D = $TorchSprite
@onready var torch_light: PointLight2D = $TorchLight
@onready var torch_sparks: GPUParticles2D = $TorchSparks

var _flicker_tween: Tween
var _ignition_tween: Tween
var _base_energy: float
var _is_igniting: bool = false


func _ready() -> void:
	_base_energy = torch_light.energy
	
	# Start completely OFF - hidden, no light, no particles
	_set_completely_off()
	
	# Setup particles if not configured
	if torch_sparks.process_material == null:
		_setup_spark_material()
	
	# If exported as lit, ignite immediately (no delay)
	if is_lit:
		_instant_light()
	else:
		# Check for darkness and ignite with effect
		call_deferred("_check_and_ignite")


func _check_and_ignite() -> void:
	## Wait for scene to be ready, then check for darkness and ignite with effect
	
	# Wait until current_scene is valid
	var max_attempts := 10
	var attempts := 0
	
	while get_tree().current_scene == null and attempts < max_attempts:
		await get_tree().process_frame
		attempts += 1
	
	var scene_root = get_tree().current_scene
	
	if scene_root == null:
		return  # Stay off
	
	# Check for darkness
	var darkness = scene_root.get_node_or_null("DarknessModulate")
	
	if not darkness:
		darkness = scene_root.get_node_or_null("CanvasModulate")
	
	if darkness and darkness is CanvasModulate:
		# Dark level detected - ignite the torch with delay and fade
		if debug_logging:
			print("[PlayerTorch] Dark level detected in ", scene_root.name, " - igniting")
		ignite()


func ignite() -> void:
	## Light the torch with a satisfying ignition effect
	## Brief delay → flame appears and grows → sparks begin
	
	if is_lit or _is_igniting:
		return
	
	_is_igniting = true
	
	# Kill any existing animation
	if _ignition_tween:
		_ignition_tween.kill()
	
	# Brief delay - feels like the torch "notices" the darkness
	await get_tree().create_timer(ignition_delay).timeout
	
	# Safety check in case we were extinguished during delay
	if not _is_igniting:
		return
	
	is_lit = true
	
	# Make sprite visible and start animation
	torch_sprite.visible = true
	torch_sprite.modulate.a = 0.0
	torch_sprite.play("default")
	
	# Enable light at zero energy
	torch_light.enabled = true
	torch_light.energy = 0.0
	
	# Create the ignition animation
	_ignition_tween = create_tween()
	_ignition_tween.set_parallel(true)
	
	# Flame sprite fades in
	_ignition_tween.tween_property(torch_sprite, "modulate:a", 1.0, ignition_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# Light grows from zero to full
	# Slightly longer than sprite for a "warmth spreading" feel
	_ignition_tween.tween_property(torch_light, "energy", _base_energy, ignition_duration * 1.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	await _ignition_tween.finished
	
	# Start sparks after flame is mostly visible (sparks fly as flame stabilizes)
	torch_sparks.emitting = true
	
	# Begin flicker effect
	if flicker_enabled:
		_start_flicker()
	
	_is_igniting = false


func extinguish() -> void:
	## Turn off the torch with a fade-out effect
	if not is_lit and not _is_igniting:
		return
	
	_is_igniting = false
	is_lit = false
	
	# Stop flicker
	if _flicker_tween:
		_flicker_tween.kill()
	
	# Stop sparks immediately (they die out naturally)
	torch_sparks.emitting = false
	
	# Kill any ignition in progress
	if _ignition_tween:
		_ignition_tween.kill()
	
	# Fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(torch_light, "energy", 0.0, extinguish_duration)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(torch_sprite, "modulate:a", 0.0, extinguish_duration)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	await tween.finished
	
	_set_completely_off()


func _set_completely_off() -> void:
	## Set torch to completely invisible/off state
	torch_light.enabled = false
	torch_light.energy = 0.0
	torch_sprite.visible = false
	torch_sprite.modulate.a = 1.0  # Reset modulate for next ignite
	torch_sparks.emitting = false


func _instant_light() -> void:
	## Immediately light without animation (for exported is_lit = true)
	is_lit = true
	torch_light.enabled = true
	torch_light.energy = _base_energy
	torch_sprite.visible = true
	torch_sprite.modulate.a = 1.0
	torch_sprite.play("default")
	torch_sparks.emitting = true
	
	if flicker_enabled:
		_start_flicker()


func _start_flicker() -> void:
	## Begin the organic light flicker effect
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


func _setup_spark_material() -> void:
	## Configure spark particles for a warm, organic fire feel
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 3.0
	mat.direction = Vector3(0, -1, 0)  # Upward
	mat.spread = 40.0
	mat.initial_velocity_min = 25.0
	mat.initial_velocity_max = 35.0
	mat.gravity = Vector3(0, 15, 0)  # Slight gravity to arc
	mat.damping_min = 8.0
	mat.damping_max = 12.0
	mat.scale_min = 1.5
	mat.scale_max = 2.5
	
	# Fade curve for sparks
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 1))
	alpha_curve.add_point(Vector2(0.6, 0.7))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	# Color gradient - warm orange to transparent
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.8, 0.5))
	grad.add_point(0.7, Color(1.0, 0.5, 0.2, 0.5))
	grad.add_point(1.0, Color.TRANSPARENT)
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = grad
	mat.color_ramp = gradient_texture
	
	torch_sparks.process_material = mat
	torch_sparks.amount = 6
	torch_sparks.lifetime = 0.5
