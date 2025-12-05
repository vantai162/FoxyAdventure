extends Node2D
class_name GlowingCrystal
## Crystal Light Source - Diamond/Ace shape with sparkle effects
## Illuminates dark cave areas with magical twinkling glow
## Essential for Level 3 darkness mechanics

@export_group("Light Settings")
@export var base_energy: float = 1.2  ## Base light brightness (stronger default)
@export var pulse_amount: float = 0.4  ## How much energy varies during pulse
@export var pulse_speed: float = 2.0  ## Pulse frequency (higher = faster)
@export var light_color: Color = Color(0.4, 0.9, 0.6, 1.0)  ## Cyan-green glow
@export var light_radius: float = 120.0  ## How far light reaches

@export_group("Shadow Settings")
@export var cast_shadows: bool = true  ## Light blocked by walls with LightOccluder2D

@export_group("Crystal Appearance")
@export var crystal_color: Color = Color(0.6, 1.0, 0.8, 1.0)  ## Crystal tint
@export var crystal_scale: float = 1.0  ## Overall size multiplier
@export_enum("Small:0", "Medium:1", "Large:2", "Cluster:3") var crystal_type: int = 1

@export_group("Sparkle Settings")
@export var enable_sparkles: bool = true  ## Enable twinkle particle effects
@export var sparkle_intensity: float = 1.0  ## Sparkle brightness multiplier
@export var sparkle_count: int = 8  ## Number of sparkle particles

@export_group("Color Presets")
@export_enum("Emerald:0", "Sapphire:1", "Ruby:2", "Amethyst:3", "Gold:4", "Ice:5", "Custom:6") var color_preset: int = 0

@export_group("Interaction")
@export var react_to_player: bool = false  ## Brighten when player nearby
@export var reaction_radius: float = 60.0
@export var reaction_boost: float = 0.5  ## Extra brightness when triggered

var time_offset: float = 0.0
var player_nearby: bool = false
var light: PointLight2D
var detection_area: Area2D
var sparkle_particles: GPUParticles2D
var sparkle_points: Array[Node2D] = []

# Color preset definitions
const COLOR_PRESETS = {
	0: {"light": Color(0.3, 1.0, 0.5), "crystal": Color(0.5, 1.0, 0.7)},  # Emerald
	1: {"light": Color(0.3, 0.6, 1.0), "crystal": Color(0.5, 0.7, 1.0)},  # Sapphire
	2: {"light": Color(1.0, 0.3, 0.4), "crystal": Color(1.0, 0.5, 0.6)},  # Ruby
	3: {"light": Color(0.8, 0.4, 1.0), "crystal": Color(0.9, 0.6, 1.0)},  # Amethyst
	4: {"light": Color(1.0, 0.85, 0.3), "crystal": Color(1.0, 0.9, 0.5)}, # Gold
	5: {"light": Color(0.7, 0.95, 1.0), "crystal": Color(0.85, 1.0, 1.0)}, # Ice
}

func _ready() -> void:
	time_offset = randf() * TAU  # Random phase offset for variety
	
	# Apply color preset
	if color_preset != 6:  # Not custom
		var preset = COLOR_PRESETS.get(color_preset, COLOR_PRESETS[0])
		light_color = preset.light
		crystal_color = preset.crystal
	
	_create_diamond_crystal()
	_setup_light()
	
	if enable_sparkles:
		_setup_sparkles()
	
	if react_to_player:
		_setup_detection_area()

func _process(delta: float) -> void:
	var time = Time.get_ticks_msec() / 1000.0
	var pulse = sin((time * pulse_speed) + time_offset) * 0.5 + 0.5  # 0 to 1
	
	var target_energy = base_energy + (pulse * pulse_amount)
	if player_nearby:
		target_energy += reaction_boost
	
	if light:
		light.energy = target_energy
	
	# Animate sparkle points
	_animate_sparkles(time)

func _setup_light() -> void:
	light = PointLight2D.new()
	light.name = "CrystalLight"
	light.color = light_color
	light.energy = base_energy
	light.texture_scale = light_radius / 128.0
	
	# Enable shadow casting so walls block light
	light.shadow_enabled = cast_shadows
	
	# Create radial gradient texture
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
	
	add_child(light)

func _setup_detection_area() -> void:
	detection_area = Area2D.new()
	detection_area.name = "DetectionArea"
	detection_area.collision_layer = 0
	detection_area.collision_mask = 2  # Player layer
	
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle = CircleShape2D.new()
	circle.radius = reaction_radius
	collision.shape = circle
	
	detection_area.add_child(collision)
	add_child(detection_area)
	
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false

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
	
	# Diamond/ace proportions - wider points for that playing card feel
	var h = 20.0 * size  # Half height (total height = 40)
	var w = 12.0 * size  # Half width (total width = 24)
	var pinch = 0.15     # How much the middle pinches in (0 = straight edges)
	
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

func _setup_sparkles() -> void:
	# Create multiple sparkle points that twinkle
	var radius = 25.0 * crystal_scale
	
	for i in range(sparkle_count):
		var sparkle = Node2D.new()
		sparkle.name = "Sparkle_%d" % i
		
		# Random position around crystal
		var angle = (float(i) / sparkle_count) * TAU + randf_range(-0.3, 0.3)
		var dist = radius * randf_range(0.5, 1.2)
		sparkle.position = Vector2(cos(angle) * dist, sin(angle) * dist)
		
		# Create 4-pointed star shape for sparkle
		var star = _create_sparkle_star(3.0 * crystal_scale)
		star.modulate = light_color
		star.modulate.a = 0.0  # Start invisible
		sparkle.add_child(star)
		
		# Store timing data
		sparkle.set_meta("phase", randf() * TAU)
		sparkle.set_meta("speed", randf_range(2.0, 4.0))
		sparkle.set_meta("star", star)
		
		add_child(sparkle)
		sparkle_points.append(sparkle)

func _create_sparkle_star(size: float) -> Polygon2D:
	var star = Polygon2D.new()
	star.name = "StarShape"
	
	# 4-pointed star / twinkle shape
	var outer = size
	var inner = size * 0.25  # Sharp points
	
	var points: PackedVector2Array = []
	for i in range(8):
		var angle = (float(i) / 8.0) * TAU - PI / 2.0
		var r = outer if i % 2 == 0 else inner
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
	
	star.polygon = points
	star.color = Color.WHITE
	return star

func _animate_sparkles(time: float) -> void:
	for sparkle in sparkle_points:
		var phase = sparkle.get_meta("phase", 0.0)
		var speed = sparkle.get_meta("speed", 3.0)
		var star = sparkle.get_meta("star") as Polygon2D
		
		if star:
			# Twinkle: fade in/out with sharp peaks
			var t = sin((time * speed) + phase)
			var alpha = pow(max(0.0, t), 2.0) * sparkle_intensity  # Sharp peaks
			star.modulate.a = alpha
			
			# Slight scale pulse
			var s = 0.8 + alpha * 0.4
			star.scale = Vector2(s, s)
			
			# Subtle rotation
			star.rotation = time * 0.5

## Set crystal color (for variety)
func set_glow_color(new_color: Color) -> void:
	light_color = new_color
	crystal_color = new_color.lightened(0.2)
	if light:
		light.color = new_color
	
	# Update sparkle colors
	for sparkle in sparkle_points:
		var star = sparkle.get_meta("star") as Polygon2D
		if star:
			star.modulate = new_color
			star.modulate.a = star.modulate.a  # Preserve alpha

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
		tween.tween_property(light, "energy", base_energy if lit else 0.0, 0.3)
	visible = lit
