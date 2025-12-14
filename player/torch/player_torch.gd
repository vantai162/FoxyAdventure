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
## Delay before torch ignites after entering darkness
## This is INTENTIONAL for immersion - the fox "notices" the darkness, then responds
## The player sees darkness first, THEN the fox pulls out the torch
## 0.4-0.5s feels organic: transition completes → moment of darkness → fox reacts
@export var ignition_delay: float = 0.45
## How long the flame fades in (like lighting a match)
@export var ignition_duration: float = 0.4
## How long to fade out when extinguishing
@export var extinguish_duration: float = 0.2

@export_group("Re-ignition")
## Delay before torch can re-ignite after being extinguished (e.g., after swimming)
## This is a SIGNIFICANT penalty - a wet torch takes TIME to dry!
## 5+ seconds forces the player to navigate in darkness, punishing careless water entry
## Design: "The player if jumps in water in a dark level should be penalized for it"
@export var reignition_delay: float = 6.0
## Whether to automatically re-ignite in darkness after extinguishing
## Set to false if you want the torch to stay out permanently (harsher penalty)
@export var auto_reignite: bool = true

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
var _was_extinguished_by_water: bool = false  ## Track if we need to re-ignite


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


func extinguish(reason: String = "unknown") -> void:
	## Turn off the torch with a fade-out effect
	## @param reason: Why the torch is being extinguished ("water", "death", "manual")
	##                Used to determine if re-ignition should happen
	if not is_lit and not _is_igniting:
		return
	
	_is_igniting = false
	is_lit = false
	
	# Track if this was a water extinguish (for re-ignition)
	_was_extinguished_by_water = (reason == "water")
	
	if debug_logging:
		print("[PlayerTorch] Extinguishing - reason: ", reason, ", will reignite: ", _was_extinguished_by_water and auto_reignite)
	
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


func try_reignite() -> void:
	## Called when player exits water - attempt to re-ignite if in darkness
	## The torch was wet, so it takes longer to catch fire again
	
	if not auto_reignite:
		return
	
	if not _was_extinguished_by_water:
		return  # Only auto-reignite if extinguished by water
	
	if is_lit or _is_igniting:
		return  # Already lit or igniting
	
	# Check if we're still in a dark level
	if not _is_in_darkness():
		if debug_logging:
			print("[PlayerTorch] Not in darkness, skipping reignite")
		return
	
	if debug_logging:
		print("[PlayerTorch] Attempting re-ignition after water (delay: ", reignition_delay, "s)")
	
	# Clear the flag
	_was_extinguished_by_water = false
	
	# Re-ignite with longer delay (drying out)
	_reignite_after_delay()


func _reignite_after_delay() -> void:
	## Internal: ignite with the longer reignition delay
	if is_lit or _is_igniting:
		return
	
	_is_igniting = true
	
	# Kill any existing animation
	if _ignition_tween:
		_ignition_tween.kill()
	
	# Longer delay - the torch was wet and needs to dry!
	await get_tree().create_timer(reignition_delay).timeout
	
	# Safety check
	if not _is_igniting:
		return
	
	# Double-check we're still in darkness (player might have moved to bright area)
	if not _is_in_darkness():
		_is_igniting = false
		if debug_logging:
			print("[PlayerTorch] Left darkness during drying, canceling reignite")
		return
	
	is_lit = true
	
	# Same ignition animation as normal
	torch_sprite.visible = true
	torch_sprite.modulate.a = 0.0
	torch_sprite.play("default")
	
	torch_light.enabled = true
	torch_light.energy = 0.0
	
	_ignition_tween = create_tween()
	_ignition_tween.set_parallel(true)
	
	_ignition_tween.tween_property(torch_sprite, "modulate:a", 1.0, ignition_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	_ignition_tween.tween_property(torch_light, "energy", _base_energy, ignition_duration * 1.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	await _ignition_tween.finished
	
	torch_sparks.emitting = true
	
	if flicker_enabled:
		_start_flicker()
	
	_is_igniting = false
	
	if debug_logging:
		print("[PlayerTorch] Re-ignition complete!")


func _is_in_darkness() -> bool:
	## Check if the current scene has a darkness modulate
	var scene_root = get_tree().current_scene
	if scene_root == null:
		return false
	
	var darkness = scene_root.get_node_or_null("DarknessModulate")
	if not darkness:
		darkness = scene_root.get_node_or_null("CanvasModulate")
	
	return darkness != null and darkness is CanvasModulate


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
