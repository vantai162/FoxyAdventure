extends Node2D
class_name GlowingCrystal
## Crystal Light Source - Diamond/Ace shape with sparkle effects
## Illuminates dark cave areas with magical twinkling glow
## Essential for Level 3 darkness mechanics
##
## SETUP: Scene includes a PointLight2D child "CrystalLight" - configure its
## color, energy, texture_scale in the editor. Script handles pulse animation.

@export_group("Pulse Animation")
@export var pulse_amount: float = 0.4  ## How much energy varies during pulse
@export var pulse_speed: float = 2.0  ## Pulse frequency (higher = faster)

@export_group("Crystal Appearance")
@export var crystal_texture: Texture2D = null  ## Assign sprite texture for GPU rendering (drawn upright ♦, no rotation)
@export var crystal_scale: float = 1.0  ## Overall size multiplier
@export_enum("Small:0", "Medium:1", "Large:2", "Cluster:3") var crystal_type: int = 1

@export_group("Color Preset")
@export_enum("Emerald:0", "Sapphire:1", "Ruby:2", "Amethyst:3", "Gold:4", "Ice:5") var color_preset: int = 0

@export_group("Sparkle Settings")
@export var enable_sparkles: bool = true  ## Enable twinkle particle effects
@export var sparkle_intensity: float = 1.0  ## Sparkle brightness multiplier
@export var sparkle_count: int = 8  ## Number of sparkle particles

@export_group("Performance")
@export var cast_shadows: bool = false  ## Enable shadow casting (expensive - use for 3-5 "hero" crystals only!)
## Note: VisibleOnScreenEnabler2D handles culling automatically

## Scene node references
@onready var light: PointLight2D = $CrystalLight
@onready var sparkles: GPUParticles2D = $Sparkles
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibilityEnabler

## Runtime state
var _base_energy: float = 1.0
var _base_color: Color = Color(0.3, 1.0, 0.5)  ## Emerald default
var crystal_color: Color = Color(0.5, 1.0, 0.7)  ## Lighter for crystal body
var _pulse_tween: Tween

# Color preset definitions (dungeon-appropriate - dim and moody)
const COLOR_PRESETS = {
	0: {"light": Color(0.3, 1.0, 0.5), "crystal": Color(0.5, 1.0, 0.7)},  # Emerald (default dungeon green)
	1: {"light": Color(0.3, 0.6, 1.0), "crystal": Color(0.5, 0.7, 1.0)},  # Sapphire (cold blue)
	2: {"light": Color(1.0, 0.3, 0.4), "crystal": Color(1.0, 0.5, 0.6)},  # Ruby (danger red)
	3: {"light": Color(0.8, 0.4, 1.0), "crystal": Color(0.9, 0.6, 1.0)},  # Amethyst (mystic purple)
	4: {"light": Color(1.0, 0.8, 0.3), "crystal": Color(1.0, 0.9, 0.5)}, # Gold (treasure glow)
	5: {"light": Color(0.6, 0.9, 1.0), "crystal": Color(0.8, 0.95, 1.0)}, # Ice (frozen blue-white)
}

func _ready() -> void:
	# Apply color preset FIRST (before capturing from scene)
	var preset = COLOR_PRESETS.get(color_preset, COLOR_PRESETS[0])
	crystal_color = preset.crystal
	
	# Capture base values from scene-configured light, then override with preset
	if light:
		_base_energy = light.energy
		light.color = preset.light  # Apply preset color to light
		light.shadow_enabled = cast_shadows  # Apply shadow setting
		_base_color = preset.light
		if light.texture == null:
			_setup_light_texture()
	
	# GPU-rendered sprite or CPU fallback
	if crystal_texture:
		_create_sprite_crystal()
	else:
		push_warning("GlowingCrystal: No crystal_texture assigned - using CPU-rendered procedural fallback (assign Texture2D for production)")
		_create_diamond_crystal()
	
	if enable_sparkles:
		_setup_sparkles_gpu()
	else:
		sparkles.emitting = false
	
	# Setup visibility culling
	if visibility_enabler:
		visibility_enabler.screen_entered.connect(_on_screen_entered)
		visibility_enabler.screen_exited.connect(_on_screen_exited)
		# Initial state check (assume visible if just spawned, or let engine handle)
		# But we start the pulse anyway
	
	_start_pulse()

func _on_screen_entered() -> void:
	# Re-enable animations when visible
	if enable_sparkles and sparkles:
		sparkles.emitting = true
	_start_pulse()

func _on_screen_exited() -> void:
	# Disable expensive effects when offscreen, but KEEP LIGHT ON
	# (Light without shadows is cheap, and this prevents jarring pop-in/out)
	if enable_sparkles and sparkles:
		sparkles.emitting = false
	if _pulse_tween:
		_pulse_tween.kill()
	# Light stays enabled! Player won't see jarring on/off at screen edges

func _start_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	
	if not light or not light.enabled:
		return
		
	_pulse_tween = create_tween().set_loops()
	var duration = 1.0 / max(0.1, pulse_speed)
	# Pulse up
	_pulse_tween.tween_property(light, "energy", _base_energy + pulse_amount, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Pulse down
	_pulse_tween.tween_property(light, "energy", _base_energy - pulse_amount, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _setup_sparkles_gpu() -> void:
	if not sparkles:
		return
		
	sparkles.amount = sparkle_count
	sparkles.modulate = _base_color
	sparkles.lifetime = 1.5  # Longer lifetime for visibility
	sparkles.randomness = 0.6
	
	# WELDING SPARK STYLE - like lava embers but omnidirectional
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0 * crystal_scale  # Small emission zone
	mat.direction = Vector3(0, -1, 0)  # Base upward direction
	mat.spread = 180.0  # Full sphere spread (all directions!)
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, 10, 0)  # Fall down (Godot Y+ is down!)
	mat.damping_min = 5.0  # Slow down over time
	mat.damping_max = 10.0
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	
	# Fade and shrink over lifetime
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 1))
	alpha_curve.add_point(Vector2(0.7, 0.6))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1))
	scale_curve.add_point(Vector2(1, 0.3))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex
	
	sparkles.process_material = mat
	
	# Use GradientTexture1D for color_ramp (like whirlpool)
	var grad = Gradient.new()
	grad.add_point(0.0, crystal_color)
	grad.add_point(0.7, crystal_color * 0.5)
	grad.add_point(1.0, Color.TRANSPARENT)
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = grad
	mat.color_ramp = gradient_texture


func _setup_light_texture() -> void:
	## Smooth radial gradient for light - particles are sharp, not the light!
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
	light.texture = gradient

func _create_sprite_crystal() -> void:
	## GPU-rendered sprite crystal (production ready)
	var sprite = Sprite2D.new()
	sprite.name = "CrystalSprite"
	sprite.texture = crystal_texture
	sprite.modulate = crystal_color
	
	# Apply scale based on crystal type
	var size = crystal_scale
	match crystal_type:
		0:  # Small
			size *= 0.6
		1:  # Medium
			size *= 1.0
		2:  # Large
			size *= 1.5
		3:  # Cluster
			size *= 1.2  # Cluster uses single large sprite
	
	sprite.scale = Vector2(size, size)
	add_child(sprite)

func _create_diamond_crystal() -> void:
	var size = crystal_scale
	match crystal_type:
		0:  # Small
			size *= 0.6
		1:  # Medium
			size *= 1.0
		2:  # Large
			size *= 1.5
		3:  # Cluster
			_create_diamond_cluster()
			return
	
	_create_single_diamond(size, Vector2.ZERO, 0.0)

func _create_single_diamond(size: float, offset: Vector2, rot: float) -> void:
	# Main diamond shape - like ♦ ace card / 4-pointed star
	var diamond = Polygon2D.new()
	diamond.name = "DiamondShape"
	diamond.position = offset
	diamond.rotation = rot
	
	# Diamond/ace proportions - SMALLER for dungeon feel
	var h = 12.0 * size  # Half height (was 20, now 12)
	var w = 8.0 * size   # Half width (was 12, now 8)
	var pinch = 0.15     # How much the middle pinches in
	
	# 4-pointed diamond with slight curves via extra points
	diamond.polygon = PackedVector2Array([
		Vector2(0, -h),              # Top point
		Vector2(w * pinch, -h * 0.5),   # Upper right curve
		Vector2(w, 0),               # Right point
		Vector2(w * pinch, h * 0.5),    # Lower right curve
		Vector2(0, h),               # Bottom point
		Vector2(-w * pinch, h * 0.5),   # Lower left curve
		Vector2(-w, 0),              # Left point
		Vector2(-w * pinch, -h * 0.5),  # Upper left curve
	])
	diamond.color = crystal_color
	add_child(diamond)
	
	# Inner highlight - smaller diamond for shine effect
	var highlight = Polygon2D.new()
	highlight.name = "Highlight"
	highlight.position = offset + Vector2(-w * 0.15, -h * 0.15) * size
	highlight.rotation = rot
	
	var hs = 0.4  # Highlight scale
	highlight.polygon = PackedVector2Array([
		Vector2(0, -h * hs),
		Vector2(w * hs, 0),
		Vector2(0, h * hs),
		Vector2(-w * hs, 0),
	])
	highlight.color = Color(1, 1, 1, 0.35)
	add_child(highlight)
	
	# Add secondary gleam
	var gleam = Polygon2D.new()
	gleam.name = "Gleam"
	gleam.position = offset + Vector2(w * 0.2, h * 0.1) * size
	gleam.rotation = rot
	
	var gs = 0.2
	gleam.polygon = PackedVector2Array([
		Vector2(0, -h * gs),
		Vector2(w * gs * 0.5, 0),
		Vector2(0, h * gs),
		Vector2(-w * gs * 0.5, 0),
	])
	gleam.color = Color(1, 1, 1, 0.2)
	add_child(gleam)

func _create_diamond_cluster() -> void:
	# Central large diamond
	_create_single_diamond(1.0 * crystal_scale, Vector2.ZERO, 0.0)
	
	# Smaller diamonds around it at various angles
	var cluster_data = [
		{"offset": Vector2(-14, 6), "size": 0.45, "rot": -0.2},
		{"offset": Vector2(12, 8), "size": 0.5, "rot": 0.15},
		{"offset": Vector2(-8, -10), "size": 0.35, "rot": 0.3},
		{"offset": Vector2(10, -6), "size": 0.4, "rot": -0.25},
		{"offset": Vector2(0, 12), "size": 0.3, "rot": 0.1},
	]
	
	for data in cluster_data:
		var mini_color = crystal_color.darkened(randf_range(0.0, 0.15))
		_create_mini_diamond(
			data.size * crystal_scale,
			data.offset * crystal_scale,
			data.rot,
			mini_color
		)

func _create_mini_diamond(size: float, offset: Vector2, rot: float, col: Color) -> void:
	var mini = Polygon2D.new()
	mini.name = "MiniDiamond"
	mini.position = offset
	mini.rotation = rot
	
	var h = 12.0 * size
	var w = 7.0 * size
	
	mini.polygon = PackedVector2Array([
		Vector2(0, -h),
		Vector2(w, 0),
		Vector2(0, h),
		Vector2(-w, 0),
	])
	mini.color = col
	add_child(mini)

## Set crystal color (for variety)
func set_glow_color(new_color: Color) -> void:
	_base_color = new_color
	crystal_color = new_color.lightened(0.2)
	if light:
		light.color = new_color
	if sparkles:
		sparkles.modulate = new_color
	
	# Restart pulse to pick up new base energy if needed
	_start_pulse()

## Apply a color preset by index
func apply_preset(preset_index: int) -> void:
	if preset_index in COLOR_PRESETS:
		var preset = COLOR_PRESETS[preset_index]
		set_glow_color(preset.light)
		crystal_color = preset.crystal

## Turn light on/off (for puzzles)
func set_lit(lit: bool) -> void:
	if light:
		var tween = create_tween()
		tween.tween_property(light, "energy", _base_energy if lit else 0.0, 0.3)
		if lit:
			_start_pulse()
		else:
			if _pulse_tween:
				_pulse_tween.kill()
	
	if sparkles:
		sparkles.emitting = lit
	
	visible = lit
