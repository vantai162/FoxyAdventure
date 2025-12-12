@tool
extends Node2D
class_name Lavafall
## Vertical lava sheet (lavafall) with animated wavy surfaces
##
## Part of the LAVA ECOSYSTEM - designed to match lava_pool.gd behavior:
## - INSTANT KILL on contact (default) - lava is deadly!
## - Viscous wave animation (slower than water, goopier)
## - Deep orange-red coloring with nearly opaque fill
## - Glowing light emission (lava illuminates darkness)
## - Rising ember particles (not water splashes)
##
## USAGE:
## - Freestanding lavafall (middle of room): surface_mode = BOTH
## - Against right wall: surface_mode = LEFT_SURFACE  
## - Against left wall: surface_mode = RIGHT_SURFACE
## - Stack multiple vertically for tall lavafalls
## - Place above lava_pool to create source effect

enum SurfaceMode {
	LEFT_SURFACE,   ## Wavy surface on left only (attached to right wall)
	RIGHT_SURFACE,  ## Wavy surface on right only (attached to left wall)
	BOTH_SURFACES   ## Freestanding - both sides are wavy surfaces
}

@export var lavafall_size: Vector2 = Vector2(32.0, 128.0):
	set(value):
		lavafall_size = value
		if is_inside_tree():
			_rebuild()

@export var surface_mode: SurfaceMode = SurfaceMode.BOTH_SURFACES:
	set(value):
		surface_mode = value
		if is_inside_tree():
			_rebuild()

@export_range(2, 128) var segment_count: int = 20  ## Slightly fewer than water (thicker fluid)

## === VISUALS (matching lava_pool.gd palette) ===
@export_group("Visuals")
@export var surface_line_thickness: float = 3.0  ## Thicker than water (viscous)
@export var surface_color: Color = Color(1.0, 0.6, 0.1, 1.0)  ## Bright orange edge (hottest part)
@export var lava_fill_color: Color = Color(0.9, 0.3, 0.05, 0.95)  ## Deep orange-red, nearly opaque
@export var enable_antialiasing: bool = true

## === AMBIENT WAVES (slower, goopier than water) ===
@export_group("Ambient Waves")
@export var ambient_wave_enabled: bool = true
@export var ambient_wave_amplitude_top: float = 3.0  ## Wave depth at top (calmer source)
@export var ambient_wave_amplitude_bottom: float = 5.0  ## Wave depth at bottom (more turbulent)
@export var ambient_wave_speed: float = 1.0  ## Slower than water (thick lava)
@export var ambient_wave_length: float = 0.4  ## Longer wavelength (goopier)
@export var organic_waves: bool = true  ## Multi-frequency for natural goopy feel

## === FLOW ANIMATION (oozing, not splashing) ===
@export_group("Flow Animation")
@export var flow_enabled: bool = true
@export var flow_speed: float = 40.0  ## Slower than water - lava oozes down

## === DAMAGE (matching lava_pool.gd - INSTANT KILL default) ===
@export_group("Damage")
@export var instant_kill: bool = true  ## CRITICAL: Lava kills on contact!
@export var damage_per_second: float = 50.0  ## If not instant kill, high DPS
@export var damage_interval: float = 0.25

## === GLOW LIGHT (lava illuminates!) ===
@export_group("Glow Light")
@export var emit_light: bool = true  ## ON by default - lava glows!
@export var light_color: Color = Color(1.0, 0.5, 0.1, 1.0)  ## Orange glow
@export var light_energy: float = 1.2  ## Bright illumination
@export var light_sample_points: int = 3  ## Distributed along height
@export var light_pulse_enabled: bool = true  ## Flickering glow
@export var light_pulse_speed: float = 3.0
@export var light_pulse_amount: float = 0.3

## === EMBER PARTICLES (not water splashes!) ===
@export_group("Ember Particles")
@export var emit_embers: bool = true
@export var ember_count: int = 8
@export var ember_rise_speed: float = 25.0
@export var ember_lifetime: float = 1.5

## === IMPACT ZONE (Bottom) ===
@export_group("Impact Zone")
@export var soft_bottom_edge: bool = true  ## Fade out bottom for natural merge with pool
@export var bottom_fade_percent: float = 0.2  ## Lava is thicker, less fade than water
@export var impact_heat_enabled: bool = true  ## Hot glow particles at bottom
@export var impact_heat_count: int = 6

var segment_data: Array = []
var _ambient_wave_time: float = 0.0
var _flow_offset: float = 0.0
var _light_pulse_time: float = 0.0
var _damage_timers: Dictionary = {}

var surface_line_left: Line2D
var surface_line_right: Line2D
var fill_polygon: Polygon2D
var lava_area: Area2D
var lava_collision_shape: CollisionShape2D
var _lava_lights: Array[PointLight2D] = []
var _ember_particles: GPUParticles2D
var _impact_heat: GPUParticles2D

@export_tool_button("Update Lavafall") var update_button: Callable = func():
	_rebuild()
	_update_visuals()

func _ready() -> void:
	_rebuild()
	set_process(true)

func _rebuild() -> void:
	# Clean up existing children
	for child in get_children():
		child.queue_free()
	
	segment_data.clear()
	_damage_timers.clear()
	_lava_lights.clear()
	surface_line_left = null
	surface_line_right = null
	
	_initiate_lavafall()
	_update_visuals()

func _process(delta: float) -> void:
	# Ambient wave animation
	if ambient_wave_enabled:
		_ambient_wave_time += delta
	
	# Flow animation (waves moving downward - slowly, oozing)
	if flow_enabled:
		_flow_offset += flow_speed * delta
		if _flow_offset > lavafall_size.y * 2:
			_flow_offset -= lavafall_size.y * 2
	
	# Light pulsing (flickering glow)
	if light_pulse_enabled and _lava_lights.size() > 0:
		_update_light_pulse(delta)
	
	_update_visuals()
	
	# Editor mode: only visuals
	if Engine.is_editor_hint():
		return
	
	# Runtime: damage ticks for non-instant-kill mode
	if not instant_kill:
		_update_damage_ticks(delta)

func _initiate_lavafall() -> void:
	# Initialize segment data
	for i in range(segment_count):
		segment_data.append({"offset": 0.0})
	
	# Create surface lines based on mode
	if surface_mode == SurfaceMode.LEFT_SURFACE or surface_mode == SurfaceMode.BOTH_SURFACES:
		surface_line_left = _create_surface_line()
		add_child(surface_line_left)
	
	if surface_mode == SurfaceMode.RIGHT_SURFACE or surface_mode == SurfaceMode.BOTH_SURFACES:
		surface_line_right = _create_surface_line()
		add_child(surface_line_right)
	
	# Create fill polygon
	fill_polygon = Polygon2D.new()
	fill_polygon.color = lava_fill_color
	add_child(fill_polygon)
	
	# Create damage area
	lava_area = Area2D.new()
	lava_area.name = "LavafallDamageArea"
	lava_area.monitoring = true
	lava_area.monitorable = false
	lava_area.collision_layer = 0
	lava_area.collision_mask = 2 | 8  # Player (2) + Enemy (8) - match lava_pool
	lava_area.body_entered.connect(_on_body_entered)
	lava_area.body_exited.connect(_on_body_exited)
	lava_area.visible = false
	add_child(lava_area)
	
	# Create collision shape
	lava_collision_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = lavafall_size
	lava_collision_shape.shape = rect
	lava_collision_shape.position = lavafall_size / 2.0
	lava_area.add_child(lava_collision_shape)
	
	# Setup lighting (runtime only, but calculate positions)
	if emit_light:
		_setup_lights()
	
	# Setup ember particles (runtime only)
	if emit_embers and not Engine.is_editor_hint():
		_setup_ember_particles()
	
	# Setup impact heat particles at bottom (runtime only)
	if impact_heat_enabled and not Engine.is_editor_hint():
		_setup_impact_heat()

func _create_surface_line() -> Line2D:
	var line = Line2D.new()
	line.width = surface_line_thickness
	line.default_color = surface_color
	line.antialiased = enable_antialiasing
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	return line

func _update_visuals() -> void:
	var segment_height: float = lavafall_size.y / (segment_count - 1)
	
	var left_points: Array[Vector2] = []
	var right_points: Array[Vector2] = []
	
	# Build surface points along Y axis
	for i in range(segment_count):
		var y_pos = i * segment_height
		var t = float(i) / float(segment_count - 1)  # 0.0 at top, 1.0 at bottom
		
		# Interpolate wave amplitude from top to bottom (more turbulent at bottom)
		var local_amplitude = lerp(ambient_wave_amplitude_top, ambient_wave_amplitude_bottom, t)
		
		# Calculate wave offset for this segment (slower, goopier than water)
		var wave_offset_left = 0.0
		var wave_offset_right = 0.0
		
		if ambient_wave_enabled:
			var base_phase = _ambient_wave_time * ambient_wave_speed
			base_phase += (y_pos + _flow_offset) / lavafall_size.y * TAU / ambient_wave_length
			
			if organic_waves:
				# Multi-frequency organic waves for goopy lava feel
				# Primary wave (slow, big)
				var primary = sin(base_phase) * local_amplitude
				# Secondary harmonic (slightly faster, smaller - creates goopy bulges)
				var secondary = sin(base_phase * 1.7 + 0.5) * local_amplitude * 0.3
				# Tertiary low-frequency swell (very slow undulation)
				var tertiary = sin(base_phase * 0.4 + 0.8) * local_amplitude * 0.2
				
				wave_offset_left = primary + secondary + tertiary
				
				# Right side uses slightly different phase for asymmetry (goopy masses)
				var right_phase = base_phase + 0.6
				wave_offset_right = sin(right_phase) * local_amplitude
				wave_offset_right += sin(right_phase * 1.5 + 0.2) * local_amplitude * 0.3
				wave_offset_right += sin(right_phase * 0.5 + 1.1) * local_amplitude * 0.2
			else:
				# Simple sine wave (original behavior)
				wave_offset_left = sin(base_phase) * local_amplitude
				wave_offset_right = wave_offset_left
		
		# Left surface: base at x=0, waves go outward (negative x)
		left_points.append(Vector2(-wave_offset_left, y_pos))
		
		# Right surface: base at x=width, waves go outward (positive x)
		right_points.append(Vector2(lavafall_size.x + wave_offset_right, y_pos))
	
	# Update surface lines
	if surface_line_left:
		surface_line_left.points = left_points
	if surface_line_right:
		surface_line_right.points = right_points
	
	# Build fill polygon based on mode
	if not fill_polygon:
		return
	
	var poly_points: PackedVector2Array = []
	
	match surface_mode:
		SurfaceMode.LEFT_SURFACE:
			# Left side is wavy, right side is flat (against wall)
			for p in left_points:
				poly_points.append(p)
			poly_points.append(Vector2(lavafall_size.x, lavafall_size.y))
			poly_points.append(Vector2(lavafall_size.x, 0))
		
		SurfaceMode.RIGHT_SURFACE:
			# Right side is wavy, left side is flat (against wall)
			poly_points.append(Vector2(0, 0))
			poly_points.append(Vector2(0, lavafall_size.y))
			# Add right points in reverse (bottom to top for proper winding)
			for i in range(right_points.size() - 1, -1, -1):
				poly_points.append(right_points[i])
		
		SurfaceMode.BOTH_SURFACES:
			# Both sides wavy - freestanding lavafall
			# Left edge top to bottom
			for p in left_points:
				poly_points.append(p)
			# Right edge bottom to top
			for i in range(right_points.size() - 1, -1, -1):
				poly_points.append(right_points[i])
	
	fill_polygon.polygon = poly_points
	
	# Apply vertex colors for soft bottom fade (lava merges into pool below)
	if soft_bottom_edge and poly_points.size() > 0:
		var vertex_colors: PackedColorArray = []
		var base_color = lava_fill_color
		
		for point in poly_points:
			# Calculate fade based on Y position
			var y_ratio = point.y / lavafall_size.y  # 0 at top, 1 at bottom
			var fade_start = 1.0 - bottom_fade_percent
			
			if y_ratio > fade_start:
				# In fade zone - interpolate alpha to 0
				var fade_progress = (y_ratio - fade_start) / bottom_fade_percent
				var alpha = base_color.a * (1.0 - fade_progress)
				vertex_colors.append(Color(base_color.r, base_color.g, base_color.b, alpha))
			else:
				# Above fade zone - full color
				vertex_colors.append(base_color)
		
		fill_polygon.vertex_colors = vertex_colors
	else:
		fill_polygon.vertex_colors = PackedColorArray()

func _setup_lights() -> void:
	# Create distributed lights along lavafall height
	var num_lights = clamp(light_sample_points, 1, 8)
	_lava_lights.clear()
	
	for i in range(num_lights):
		var light = PointLight2D.new()
		light.name = "LavafallGlow_%d" % i
		light.color = light_color
		light.energy = light_energy / float(num_lights) * 1.5
		light.texture_scale = 1.5
		light.shadow_enabled = (i == 0)  # Only first casts shadows
		light.z_index = 10
		light.blend_mode = Light2D.BLEND_MODE_ADD
		
		# Create radial gradient texture
		var gradient = GradientTexture2D.new()
		gradient.fill = GradientTexture2D.FILL_RADIAL
		gradient.fill_from = Vector2(0.5, 0.5)
		gradient.fill_to = Vector2(0.5, 0.0)
		var grad = Gradient.new()
		grad.set_color(0, Color.WHITE)
		grad.set_color(1, Color.TRANSPARENT)
		gradient.gradient = grad
		gradient.width = 128
		gradient.height = 128
		light.texture = gradient
		
		# Position evenly along lavafall height
		var y_pos = lavafall_size.y * (float(i) / float(num_lights - 1 if num_lights > 1 else 1))
		light.position = Vector2(lavafall_size.x / 2.0, y_pos)
		
		add_child(light)
		_lava_lights.append(light)

func _update_light_pulse(delta: float) -> void:
	_light_pulse_time += delta * light_pulse_speed
	
	# Flickering effect using multiple sine waves for organic feel
	var flicker = sin(_light_pulse_time) * 0.5 + 0.5
	flicker += sin(_light_pulse_time * 2.3) * 0.3
	flicker += sin(_light_pulse_time * 0.7) * 0.2
	flicker = clamp(flicker / 2.0, 0.0, 1.0)
	
	# Apply to all lights
	for light in _lava_lights:
		if light:
			light.energy = (light_energy / float(_lava_lights.size()) * 1.5) + (flicker * light_pulse_amount)

func _setup_ember_particles() -> void:
	_ember_particles = GPUParticles2D.new()
	_ember_particles.name = "LavafallEmbers"
	_ember_particles.position = Vector2(lavafall_size.x / 2.0, lavafall_size.y / 2.0)
	_ember_particles.amount = ember_count
	_ember_particles.lifetime = ember_lifetime
	_ember_particles.randomness = 0.5
	_ember_particles.emitting = true
	
	# Configure particle material - embers rise from lavafall
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(lavafall_size.x / 2.0, lavafall_size.y / 2.0, 0)
	mat.direction = Vector3(0, -1, 0)  # Upward
	mat.spread = 15.0
	mat.initial_velocity_min = ember_rise_speed * 0.8
	mat.initial_velocity_max = ember_rise_speed * 1.2
	mat.gravity = Vector3(0, -ember_rise_speed * 0.3, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	
	# Fade out curve
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 1))
	alpha_curve.add_point(Vector2(0.5, 0.8))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	_ember_particles.process_material = mat
	
	# Create ember texture (matching lava_pool)
	var ember_tex = GradientTexture2D.new()
	ember_tex.width = 8
	ember_tex.height = 8
	ember_tex.fill = GradientTexture2D.FILL_RADIAL
	ember_tex.fill_from = Vector2(0.5, 0.5)
	ember_tex.fill_to = Vector2(0.5, 0.0)
	var ember_grad = Gradient.new()
	ember_grad.set_color(0, Color(1, 0.5, 0.1, 1))
	ember_grad.set_color(1, Color(1, 0.3, 0.0, 0))
	ember_tex.gradient = ember_grad
	_ember_particles.texture = ember_tex
	
	add_child(_ember_particles)

func _setup_impact_heat() -> void:
	# Hot glow particles at the impact zone (bottom of lavafall)
	_impact_heat = GPUParticles2D.new()
	_impact_heat.name = "ImpactHeat"
	_impact_heat.position = Vector2(lavafall_size.x / 2.0, lavafall_size.y)
	_impact_heat.amount = impact_heat_count
	_impact_heat.lifetime = 0.8
	_impact_heat.randomness = 0.5
	_impact_heat.emitting = true
	
	# Configure - intense glow that rises briefly then fades
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(lavafall_size.x / 2.0, 8, 0)
	mat.direction = Vector3(0, -1, 0)  # Upward
	mat.spread = 35.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 25.0
	mat.gravity = Vector3(0, -8.0, 0)
	mat.scale_min = 4.0
	mat.scale_max = 10.0
	
	# Bright flash then fade
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 0.7))
	alpha_curve.add_point(Vector2(0.2, 0.9))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	# Scale up as it rises
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0.6))
	scale_curve.add_point(Vector2(0.5, 1.2))
	scale_curve.add_point(Vector2(1, 0.8))
	var scale_curve_tex = CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	mat.scale_curve = scale_curve_tex
	
	_impact_heat.process_material = mat
	
	# Create hot glow texture (bright yellow-white core, orange edge)
	var heat_tex = GradientTexture2D.new()
	heat_tex.width = 16
	heat_tex.height = 16
	heat_tex.fill = GradientTexture2D.FILL_RADIAL
	heat_tex.fill_from = Vector2(0.5, 0.5)
	heat_tex.fill_to = Vector2(0.5, 0.0)
	var heat_grad = Gradient.new()
	heat_grad.set_color(0, Color(1.0, 0.9, 0.6, 0.8))  # Bright yellow-white core
	heat_grad.set_color(1, Color(1.0, 0.4, 0.1, 0.0))  # Orange fade to transparent
	heat_tex.gradient = heat_grad
	_impact_heat.texture = heat_tex
	
	add_child(_impact_heat)

## === DAMAGE HANDLING (matching lava_pool.gd exactly) ===

func _on_body_entered(body: Node2D) -> void:
	if instant_kill:
		_kill_body(body)
	else:
		# Start damage over time
		_damage_timers[body] = 0.0
		_apply_damage(body)

func _on_body_exited(body: Node2D) -> void:
	_damage_timers.erase(body)

func _kill_body(body: Node2D) -> void:
	# Player-specific kill (die method) - EXACTLY matching lava_pool.gd
	if body.is_in_group("player"):
		if body.has_method("die"):
			body.die()
		return
	
	# Enemy-specific kill (take_damage with massive damage)
	if body.has_method("take_damage"):
		if body.has_method("get_max_health"):
			body.take_damage(body.get_max_health() * 10)  # Overkill
		else:
			body.take_damage(9999)
		return
	
	# Generic fallback for any CharacterBody2D
	if body is CharacterBody2D:
		var hurt_area = body.get_node_or_null("Direction/HurtArea2D")
		if hurt_area and hurt_area.has_signal("hurt"):
			hurt_area.emit_signal("hurt", Vector2.ZERO, 9999)
		elif body.has_method("die"):
			body.die()

func _apply_damage(body: Node2D) -> void:
	if not _damage_timers.has(body):
		return
	
	var damage = damage_per_second * damage_interval
	
	if body.has_method("take_damage"):
		body.take_damage(int(damage))
	else:
		var hurt_area = body.get_node_or_null("Direction/HurtArea2D")
		if hurt_area and hurt_area.has_signal("hurt"):
			hurt_area.emit_signal("hurt", Vector2.ZERO, damage)

func _update_damage_ticks(delta: float) -> void:
	var to_remove: Array = []
	
	for body in _damage_timers.keys():
		if not is_instance_valid(body):
			to_remove.append(body)
			continue
		
		_damage_timers[body] += delta
		if _damage_timers[body] >= damage_interval:
			_damage_timers[body] -= damage_interval
			_apply_damage(body)
	
	for body in to_remove:
		_damage_timers.erase(body)
