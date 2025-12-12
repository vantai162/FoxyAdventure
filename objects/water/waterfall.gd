@tool
extends Node2D
class_name Waterfall
## Vertical water sheet (waterfall) with animated wavy surfaces
##
## Unlike regular water pools, waterfalls:
## - Are VERTICAL sheets of falling water
## - Can have wavy surface on LEFT, RIGHT, or BOTH sides
## - Player can SWIM through them (vertical swimming!)
## - Apply gentle downward push force
## - Splash when player enters from the side
##
## USAGE:
## - Freestanding waterfall (middle of room): surface_mode = BOTH
## - Against right wall: surface_mode = LEFT_SURFACE
## - Against left wall: surface_mode = RIGHT_SURFACE
## - Stack multiple vertically for tall waterfalls

enum SurfaceMode {
	LEFT_SURFACE,   ## Wavy surface on left only (attached to right wall)
	RIGHT_SURFACE,  ## Wavy surface on right only (attached to left wall)
	BOTH_SURFACES   ## Freestanding - both sides are wavy surfaces
}

@export var waterfall_size: Vector2 = Vector2(32.0, 128.0):
	set(value):
		waterfall_size = value
		if is_inside_tree():
			_rebuild()

@export var surface_mode: SurfaceMode = SurfaceMode.BOTH_SURFACES:
	set(value):
		surface_mode = value
		if is_inside_tree():
			_rebuild()

@export_range(2, 128) var segment_count: int = 24  ## Higher = smoother curves

@export_group("Visuals")
@export var surface_line_thickness: float = 2.0
@export var surface_color: Color = Color("3ce1da")
@export var water_fill_color: Color = Color(0.216, 0.690, 0.773, 0.6)
@export var enable_antialiasing: bool = true

@export_group("Ambient Waves")
@export var ambient_wave_enabled: bool = true
@export var ambient_wave_amplitude_top: float = 2.0  ## Wave depth at top (calmer source)
@export var ambient_wave_amplitude_bottom: float = 4.0  ## Wave depth at bottom (more turbulent)
@export var ambient_wave_speed: float = 2.5  ## Wave frequency
@export var ambient_wave_length: float = 0.3  ## Wavelength factor
@export var organic_waves: bool = true  ## Multi-frequency for natural feel

@export_group("Flow Animation")
@export var flow_enabled: bool = true  ## Waves move downward (falling effect)
@export var flow_speed: float = 80.0  ## Pixels per second the wave pattern moves down

@export_group("Physics")
@export var push_force: float = 150.0  ## Downward force applied to bodies in waterfall
@export var push_enabled: bool = true  ## Apply downward push to simulate falling water

@export_group("Splash Effects")
@export var splash_enabled: bool = true  ## Spawn splash particles on entry
@export var splash_particle_count: int = 6
@export var splash_particle_speed: float = 100.0
@export var splash_color: Color = Color(0.8, 0.95, 1.0, 0.9)

@export_group("Impact Zone (Bottom)")
@export var soft_bottom_edge: bool = true  ## Fade out bottom edge for natural look
@export var bottom_fade_percent: float = 0.25  ## How much of bottom fades (0.0-0.5)
@export var impact_mist_enabled: bool = true  ## Spray particles at bottom
@export var impact_mist_count: int = 8
@export var impact_mist_speed: float = 30.0  ## How fast mist rises
@export var impact_mist_spread: float = 1.5  ## Horizontal spread multiplier

@export_group("Glow Light (Optional)")
@export var emit_light: bool = false
@export var light_color: Color = Color(0.3, 0.8, 1.0, 0.8)
@export var light_energy: float = 0.5

var segment_data: Array = []
var _ambient_wave_time: float = 0.0
var _flow_offset: float = 0.0
var _bodies_in_water: Array = []
var _splash_particles: Array = []

var surface_line_left: Line2D
var surface_line_right: Line2D
var fill_polygon: Polygon2D
var water_area: Area2D
var water_collision_shape: CollisionShape2D
var _water_light: PointLight2D
var _impact_mist: GPUParticles2D

signal player_entered_water(body)
signal player_exited_water(body)

@export_tool_button("Update Waterfall") var update_button: Callable = func():
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
	_bodies_in_water.clear()
	_splash_particles.clear()
	surface_line_left = null
	surface_line_right = null
	
	_initiate_waterfall()
	_update_visuals()

func _process(delta: float) -> void:
	# Ambient wave animation
	if ambient_wave_enabled:
		_ambient_wave_time += delta
	
	# Flow animation (waves moving downward)
	if flow_enabled:
		_flow_offset += flow_speed * delta
		if _flow_offset > waterfall_size.y * 2:
			_flow_offset -= waterfall_size.y * 2
	
	_update_visuals()
	
	# Runtime only: physics and particles
	if Engine.is_editor_hint():
		return
	
	# Apply push force to bodies in waterfall
	if push_enabled:
		for body in _bodies_in_water:
			if is_instance_valid(body) and body.has_method("apply_waterfall_push"):
				body.apply_waterfall_push(Vector2(0, push_force) * delta)
			elif is_instance_valid(body) and "velocity" in body:
				# Fallback: directly add to velocity if no method
				body.velocity.y += push_force * delta
	
	# Update splash particles
	_update_splash_particles(delta)

func _initiate_waterfall() -> void:
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
	fill_polygon.color = water_fill_color
	add_child(fill_polygon)
	
	# Create collision area
	water_area = Area2D.new()
	water_area.monitoring = true
	water_area.monitorable = true
	water_area.collision_layer = 1  # Water layer
	water_area.collision_mask = 2   # Player layer
	water_area.body_entered.connect(_on_body_entered)
	water_area.body_exited.connect(_on_body_exited)
	water_area.visible = false
	add_child(water_area)
	
	# Create collision shape
	water_collision_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = waterfall_size
	water_collision_shape.shape = rect
	water_collision_shape.position = waterfall_size / 2.0
	water_area.add_child(water_collision_shape)
	
	# Optional lighting
	if emit_light and not Engine.is_editor_hint():
		_setup_light()
	
	# Impact mist at bottom (runtime only)
	if impact_mist_enabled and not Engine.is_editor_hint():
		_setup_impact_mist()

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
	var segment_height: float = waterfall_size.y / (segment_count - 1)
	
	var left_points: Array[Vector2] = []
	var right_points: Array[Vector2] = []
	
	# Build surface points along Y axis
	for i in range(segment_count):
		var y_pos = i * segment_height
		var t = float(i) / float(segment_count - 1)  # 0.0 at top, 1.0 at bottom
		
		# Interpolate wave amplitude from top to bottom (more turbulent at bottom)
		var local_amplitude = lerp(ambient_wave_amplitude_top, ambient_wave_amplitude_bottom, t)
		
		# Calculate wave offset for this segment
		var wave_offset_left = 0.0
		var wave_offset_right = 0.0
		
		if ambient_wave_enabled:
			var base_phase = _ambient_wave_time * ambient_wave_speed
			base_phase += (y_pos + _flow_offset) / waterfall_size.y * TAU / ambient_wave_length
			
			if organic_waves:
				# Multi-frequency organic waves (like natural water)
				# Primary wave
				var primary = sin(base_phase) * local_amplitude
				# Secondary harmonic (faster, smaller)
				var secondary = sin(base_phase * 2.3 + 0.7) * local_amplitude * 0.25
				# Tertiary low-frequency swell
				var tertiary = sin(base_phase * 0.6 + 1.2) * local_amplitude * 0.15
				
				wave_offset_left = primary + secondary + tertiary
				
				# Right side uses slightly different phase for asymmetry (natural feel)
				var right_phase = base_phase + 0.4
				wave_offset_right = sin(right_phase) * local_amplitude
				wave_offset_right += sin(right_phase * 2.1 + 0.3) * local_amplitude * 0.25
				wave_offset_right += sin(right_phase * 0.7 + 0.9) * local_amplitude * 0.15
			else:
				# Simple sine wave (original behavior)
				wave_offset_left = sin(base_phase) * local_amplitude
				wave_offset_right = wave_offset_left
		
		# Left surface: base at x=0, waves go outward (negative x)
		left_points.append(Vector2(-wave_offset_left, y_pos))
		
		# Right surface: base at x=width, waves go outward (positive x)
		right_points.append(Vector2(waterfall_size.x + wave_offset_right, y_pos))
	
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
			poly_points.append(Vector2(waterfall_size.x, waterfall_size.y))
			poly_points.append(Vector2(waterfall_size.x, 0))
		
		SurfaceMode.RIGHT_SURFACE:
			# Right side is wavy, left side is flat (against wall)
			poly_points.append(Vector2(0, 0))
			poly_points.append(Vector2(0, waterfall_size.y))
			# Add right points in reverse (bottom to top for proper winding)
			for i in range(right_points.size() - 1, -1, -1):
				poly_points.append(right_points[i])
		
		SurfaceMode.BOTH_SURFACES:
			# Both sides wavy - freestanding waterfall
			# Left edge top to bottom
			for p in left_points:
				poly_points.append(p)
			# Right edge bottom to top
			for i in range(right_points.size() - 1, -1, -1):
				poly_points.append(right_points[i])
	
	fill_polygon.polygon = poly_points
	
	# Apply vertex colors for soft bottom fade
	if soft_bottom_edge and poly_points.size() > 0:
		var vertex_colors: PackedColorArray = []
		var base_color = water_fill_color
		
		for point in poly_points:
			# Calculate fade based on Y position
			var y_ratio = point.y / waterfall_size.y  # 0 at top, 1 at bottom
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

func _setup_light() -> void:
	_water_light = PointLight2D.new()
	_water_light.color = light_color
	_water_light.energy = light_energy
	_water_light.texture_scale = 1.5
	_water_light.position = waterfall_size / 2.0
	
	# Create radial gradient texture
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center = Vector2(32, 32)
	for x in range(64):
		for y in range(64):
			var dist = Vector2(x, y).distance_to(center) / 32.0
			var alpha = clamp(1.0 - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	var tex = ImageTexture.create_from_image(img)
	_water_light.texture = tex
	add_child(_water_light)

func _setup_impact_mist() -> void:
	_impact_mist = GPUParticles2D.new()
	_impact_mist.name = "ImpactMist"
	# Position at bottom center of waterfall
	_impact_mist.position = Vector2(waterfall_size.x / 2.0, waterfall_size.y)
	_impact_mist.amount = impact_mist_count
	_impact_mist.lifetime = 1.2
	_impact_mist.randomness = 0.4
	_impact_mist.emitting = true
	
	# Configure particle material - mist rises upward and spreads
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(waterfall_size.x / 2.0 * impact_mist_spread, 4, 0)
	mat.direction = Vector3(0, -1, 0)  # Upward
	mat.spread = 25.0  # Spread angle
	mat.initial_velocity_min = impact_mist_speed * 0.7
	mat.initial_velocity_max = impact_mist_speed * 1.3
	mat.gravity = Vector3(0, -impact_mist_speed * 0.2, 0)  # Slight upward drift
	mat.scale_min = 3.0
	mat.scale_max = 8.0
	
	# Fade out curve - mist dissolves
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 0.4))  # Start semi-transparent
	alpha_curve.add_point(Vector2(0.3, 0.6))  # Peak
	alpha_curve.add_point(Vector2(1, 0))  # Fade to nothing
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	# Scale up as it rises (mist expands)
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0.5))
	scale_curve.add_point(Vector2(1, 1.5))
	var scale_curve_tex = CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	mat.scale_curve = scale_curve_tex
	
	_impact_mist.process_material = mat
	
	# Create soft mist texture (white-ish, blurry)
	var mist_tex = GradientTexture2D.new()
	mist_tex.width = 16
	mist_tex.height = 16
	mist_tex.fill = GradientTexture2D.FILL_RADIAL
	mist_tex.fill_from = Vector2(0.5, 0.5)
	mist_tex.fill_to = Vector2(0.5, 0.0)
	var mist_grad = Gradient.new()
	# White-blue mist color matching water
	mist_grad.set_color(0, Color(0.9, 0.98, 1.0, 0.5))
	mist_grad.set_color(1, Color(0.7, 0.9, 0.95, 0.0))
	mist_tex.gradient = mist_grad
	_impact_mist.texture = mist_tex
	
	add_child(_impact_mist)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("can_interact_with_water") or body.is_in_group("player"):
		if not _bodies_in_water.has(body):
			_bodies_in_water.append(body)
		
		# Spawn splash particles
		if splash_enabled and not Engine.is_editor_hint():
			_spawn_splash(body.global_position, body.velocity if "velocity" in body else Vector2.ZERO)
		
		player_entered_water.emit(body)

func _on_body_exited(body: Node2D) -> void:
	if _bodies_in_water.has(body):
		_bodies_in_water.erase(body)
	
	# Exit splash
	if splash_enabled and not Engine.is_editor_hint():
		_spawn_splash(body.global_position, body.velocity if "velocity" in body else Vector2.ZERO)
	
	player_exited_water.emit(body)

func _spawn_splash(pos: Vector2, velocity: Vector2) -> void:
	var local_pos = to_local(pos)
	var impact_strength = velocity.length() * 0.01
	
	for i in range(splash_particle_count):
		var particle = _create_splash_particle()
		particle.position = local_pos
		
		# Random outward direction, biased by entry velocity
		var angle = randf_range(-PI, PI)
		var speed = splash_particle_speed * (0.5 + randf() * 0.5) * (1.0 + impact_strength)
		particle.set_meta("velocity", Vector2(cos(angle), sin(angle)) * speed)
		particle.set_meta("lifetime", 0.0)
		particle.set_meta("max_lifetime", 0.5 + randf() * 0.3)
		
		add_child(particle)
		_splash_particles.append(particle)

func _create_splash_particle() -> Node2D:
	var particle = Node2D.new()
	
	# Simple colored rectangle as particle
	var sprite = Sprite2D.new()
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(splash_color)
	sprite.texture = ImageTexture.create_from_image(img)
	particle.add_child(sprite)
	
	return particle

func _update_splash_particles(delta: float) -> void:
	var to_remove: Array = []
	
	for particle in _splash_particles:
		if not is_instance_valid(particle):
			to_remove.append(particle)
			continue
		
		var vel: Vector2 = particle.get_meta("velocity", Vector2.ZERO)
		var lifetime: float = particle.get_meta("lifetime", 0.0)
		var max_life: float = particle.get_meta("max_lifetime", 1.0)
		
		# Apply gravity
		vel.y += 400.0 * delta
		particle.set_meta("velocity", vel)
		
		# Move
		particle.position += vel * delta
		
		# Age
		lifetime += delta
		particle.set_meta("lifetime", lifetime)
		
		# Fade out
		particle.modulate.a = 1.0 - (lifetime / max_life)
		
		if lifetime >= max_life:
			to_remove.append(particle)
	
	for particle in to_remove:
		_splash_particles.erase(particle)
		if is_instance_valid(particle):
			particle.queue_free()
