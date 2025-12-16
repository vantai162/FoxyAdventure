@tool
extends Node2D
class_name Waterfall
## Vertical water sheet (waterfall) with animated wavy surfaces
##
## AUTONOMOUS BLENDING:
## Just place this above a water pool. That's it.
## - ONE toggle: `auto_blend_with_pool` (default: ON)
## - Automatically detects pool below at runtime
## - Automatically fades bottom edge
## - Automatically tells pool to suppress its surface line
## - No coordinates, no manual setup, just works™
##
## USAGE:
## 1. Place waterfall above water pool
## 2. Done. They blend automatically.
##
## SURFACE MODES:
## - BOTH_SURFACES: Freestanding waterfall (middle of room)
## - LEFT_SURFACE: Against right wall
## - RIGHT_SURFACE: Against left wall

enum SurfaceMode {
	LEFT_SURFACE,   ## Wavy surface on left only (attached to right wall)
	RIGHT_SURFACE,  ## Wavy surface on right only (attached to left wall)
	BOTH_SURFACES   ## Freestanding - both sides are wavy surfaces
}

## === CORE SETTINGS (the only things you NEED to touch) ===
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

## THE MAGIC TOGGLE - just leave it ON
@export var auto_blend_with_pool: bool = true  ## Automatically blend with pool below

@export_group("Visuals")
@export var surface_color: Color = Color("3ce1da"):
	set(value):
		surface_color = value
		if surface_line_left:
			surface_line_left.default_color = surface_color
		if surface_line_right:
			surface_line_right.default_color = surface_color
@export var water_fill_color: Color = Color(0.216, 0.690, 0.773, 0.6):
	set(value):
		water_fill_color = value
		if fill_polygon:
			fill_polygon.color = water_fill_color
@export var surface_line_thickness: float = 2.0:
	set(value):
		surface_line_thickness = value
		if surface_line_left:
			surface_line_left.width = surface_line_thickness
		if surface_line_right:
			surface_line_right.width = surface_line_thickness
@export_range(8, 64) var segment_count: int = 24:  ## Smoothness (higher = smoother)
	set(value):
		segment_count = value
		if is_inside_tree():
			_rebuild()  # Segment count change requires structural rebuild

@export_group("Wave Animation")
@export var wave_speed: float = 2.5  ## How fast waves move
@export var wave_amplitude: float = 3.0  ## Wave size
@export var flow_speed: float = 80.0  ## Downward flow speed

@export_group("Physics")
@export var push_force: float = 150.0  ## Downward force on player
@export var push_enabled: bool = true

@export_group("Effects")
@export var impact_spray_enabled: bool = true  ## Mist at bottom
@export var splash_on_enter: bool = true  ## Splash when player enters

@export_group("Glow Light (Optional)")
@export var emit_light: bool = false:  ## Bioluminescent/magical glow
	set(value):
		emit_light = value
		if is_inside_tree():
			_rebuild_light()
@export var light_color: Color = Color(0.3, 0.8, 1.0, 0.8):  ## Glow color (cyan default, change for bioluminescent)
	set(value):
		light_color = value
		if _water_light:
			_water_light.color = value
			_rebuild_light_texture()
@export var light_energy: float = 0.6:  ## Glow brightness
	set(value):
		light_energy = value
		if _water_light:
			_water_light.energy = value
@export var light_texture_scale: float = 2.0:  ## Glow radius
	set(value):
		light_texture_scale = value
		if _water_light:
			_water_light.texture_scale = value
@export var light_pulse_enabled: bool = true  ## Gentle pulsing animation
@export var light_pulse_speed: float = 1.5  ## Pulse rate
@export var light_pulse_amount: float = 0.25  ## Pulse intensity

## === INTERNAL STATE ===
var _wave_time: float = 0.0
var _flow_offset: float = 0.0
var _light_pulse_time: float = 0.0
var _base_light_energy: float = 0.6
var _bodies_in_water: Array = []
var _detected_pool: Node2D = null
var _blend_registered: bool = false

var surface_line_left: Line2D
var surface_line_right: Line2D
var fill_polygon: Polygon2D
var water_area: Area2D
var _impact_spray: GPUParticles2D
var _water_light: PointLight2D

signal player_entered_water(body)
signal player_exited_water(body)

func _ready() -> void:
	_rebuild()
	set_process(true)
	
	# Track node removals to clean stale body references (player death scenario)
	if not Engine.is_editor_hint():
		get_tree().node_removed.connect(_on_any_node_removed)
	
	# Auto-detect pool below at runtime
	if not Engine.is_editor_hint() and auto_blend_with_pool:
		call_deferred("_auto_blend_setup")


func _exit_tree() -> void:
	# Disconnect node removal tracking
	if get_tree() and get_tree().node_removed.is_connected(_on_any_node_removed):
		get_tree().node_removed.disconnect(_on_any_node_removed)


func _on_any_node_removed(node: Node) -> void:
	# Clean stale body references when nodes are freed (e.g., player death)
	if _bodies_in_water.has(node):
		_bodies_in_water.erase(node)

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	
	_bodies_in_water.clear()
	surface_line_left = null
	surface_line_right = null
	_water_light = null
	_blend_registered = false
	
	_create_visuals()
	_create_collision()
	
	# Particles only at runtime (performance in editor)
	if impact_spray_enabled and not Engine.is_editor_hint():
		_create_impact_spray()
	
	# Light works in EDITOR for designer visibility
	if emit_light:
		_create_light()
	
	_update_visuals()

func _process(delta: float) -> void:
	_wave_time += delta
	_flow_offset += flow_speed * delta
	if _flow_offset > waterfall_size.y * 2:
		_flow_offset -= waterfall_size.y * 2
	
	_update_visuals()
	
	# Light pulsing animation (works in editor too for preview)
	if emit_light and _water_light and light_pulse_enabled:
		_light_pulse_time += delta * light_pulse_speed
		var pulse = sin(_light_pulse_time) * light_pulse_amount
		_water_light.energy = _base_light_energy * (1.0 + pulse)
	
	if Engine.is_editor_hint():
		return
	
	# Apply push force
	if push_enabled:
		for body in _bodies_in_water:
			if is_instance_valid(body) and "velocity" in body:
				body.velocity.y += push_force * delta

## ============================================
## AUTONOMOUS BLENDING (the magic)
## ============================================

func _auto_blend_setup() -> void:
	# Find pool below us
	var pool = _find_pool_below()
	if not pool:
		return
	
	_detected_pool = pool
	
	# Calculate our footprint in pool's local space
	var our_left = global_position.x
	var our_right = global_position.x + waterfall_size.x
	var pool_local_left = our_left - pool.global_position.x
	var pool_local_right = our_right - pool.global_position.x
	
	# Tell the pool to suppress its surface under us
	if pool.has_method("_receive_waterfall_blend"):
		pool._receive_waterfall_blend(pool_local_left, pool_local_right, self)
		_blend_registered = true

func _find_pool_below() -> Node2D:
	var space = get_world_2d().direct_space_state
	if not space:
		return null
	
	# Cast ray from our bottom center, going down
	var from = global_position + Vector2(waterfall_size.x / 2.0, waterfall_size.y)
	var to = from + Vector2(0, 48)  # Check 48px below
	
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var result = space.intersect_ray(query)
	if result and result.collider:
		var parent = result.collider.get_parent()
		if parent and parent is water:
			return parent
	
	return null

## ============================================
## VISUAL CREATION
## ============================================

func _create_visuals() -> void:
	# Surface lines
	if surface_mode == SurfaceMode.LEFT_SURFACE or surface_mode == SurfaceMode.BOTH_SURFACES:
		surface_line_left = _make_surface_line()
		add_child(surface_line_left)
	
	if surface_mode == SurfaceMode.RIGHT_SURFACE or surface_mode == SurfaceMode.BOTH_SURFACES:
		surface_line_right = _make_surface_line()
		add_child(surface_line_right)
	
	# Fill polygon
	fill_polygon = Polygon2D.new()
	fill_polygon.color = water_fill_color
	fill_polygon.z_as_relative = false  # Use absolute z_index
	fill_polygon.z_index = ZLayers.FLUID_FALL_BODY  # IN FRONT of player (waterfall submersion)
	add_child(fill_polygon)

func _make_surface_line() -> Line2D:
	var line = Line2D.new()
	line.width = surface_line_thickness
	line.default_color = surface_color
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.z_as_relative = false  # Use absolute z_index
	line.z_index = ZLayers.FLUID_FALL_SURFACE  # IN FRONT of player (waterfall edge)
	
	# SEAMLESS BLEND: Edge fades to ZERO at bottom
	# When fall meets pool, NO visible edge = one continuous fluid
	# The edge "becomes" part of the pool's body, not a separate line
	if auto_blend_with_pool:
		var grad = Gradient.new()
		grad.add_point(0.0, surface_color)
		grad.add_point(0.75, surface_color)  # Solid until 75%
		grad.add_point(0.92, Color(surface_color.r, surface_color.g, surface_color.b, surface_color.a * 0.4))
		grad.add_point(1.0, Color(surface_color.r, surface_color.g, surface_color.b, 0.0))  # ZERO at bottom
		line.gradient = grad
	
	return line

func _create_collision() -> void:
	water_area = Area2D.new()
	water_area.monitoring = true
	water_area.monitorable = true
	water_area.collision_layer = 1
	water_area.collision_mask = 2
	water_area.body_entered.connect(_on_body_entered)
	water_area.body_exited.connect(_on_body_exited)
	water_area.visible = false
	add_child(water_area)
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = waterfall_size
	shape.shape = rect
	shape.position = waterfall_size / 2.0
	water_area.add_child(shape)

func _create_impact_spray() -> void:
	_impact_spray = GPUParticles2D.new()
	_impact_spray.position = Vector2(waterfall_size.x / 2.0, waterfall_size.y - 8)
	_impact_spray.amount = 20  # More particles for dramatic splash
	_impact_spray.lifetime = 1.0
	_impact_spray.emitting = true
	_impact_spray.z_index = ZLayers.EFFECT_FRONT
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Emission matches the flare zone width
	mat.emission_box_extents = Vector3(waterfall_size.x * 0.6, 6, 0)
	# Spray goes OUTWARD and UP (like real splash)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 65.0  # Wider spread for dramatic effect
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 70.0
	mat.gravity = Vector3(0, 80, 0)  # Falls back down
	mat.scale_min = 1.5
	mat.scale_max = 4.0
	
	# Alpha: fade in quickly, linger, then fade out
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 0.1))
	alpha_curve.add_point(Vector2(0.15, 0.7))
	alpha_curve.add_point(Vector2(0.5, 0.5))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	# Scale: starts big, shrinks (droplet evaporating)
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1.0))
	scale_curve.add_point(Vector2(0.3, 0.8))
	scale_curve.add_point(Vector2(1, 0.3))
	var scale_curve_tex = CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	mat.scale_curve = scale_curve_tex
	
	_impact_spray.process_material = mat
	
	# Soft white-blue mist texture
	var tex = GradientTexture2D.new()
	tex.width = 16
	tex.height = 16
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad = Gradient.new()
	grad.set_color(0, Color(0.95, 1.0, 1.0, 0.6))
	grad.set_color(1, Color(0.7, 0.9, 0.95, 0.0))
	tex.gradient = grad
	_impact_spray.texture = tex
	
	add_child(_impact_spray)

func _create_light() -> void:
	_water_light = PointLight2D.new()
	_water_light.enabled = true
	_water_light.color = light_color
	_water_light.energy = light_energy
	_water_light.texture_scale = light_texture_scale
	_water_light.blend_mode = Light2D.BLEND_MODE_ADD
	_water_light.shadow_enabled = false
	_water_light.range_z_min = -100
	_water_light.range_z_max = 100
	# Position at center-top of waterfall (glow spreads down)
	_water_light.position = Vector2(waterfall_size.x / 2.0, waterfall_size.y * 0.35)
	_water_light.z_index = ZLayers.LIGHT_EFFECT
	
	# Use proper radial gradient texture
	_water_light.texture = _create_light_gradient_texture()
	
	# Store base energy for pulse animation
	_base_light_energy = light_energy
	
	add_child(_water_light)


func _create_light_gradient_texture() -> GradientTexture2D:
	## Creates soft radial gradient for waterfall glow
	var gradient := Gradient.new()
	
	# Bright center fading to transparent
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))  # White center (color tinted by light.color)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))  # Transparent edges
	
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)  # Center
	tex.fill_to = Vector2(0.0, 0.5)     # Radial outward
	
	return tex


func _rebuild_light() -> void:
	## Rebuild light when emit_light is toggled in editor
	if _water_light:
		_water_light.queue_free()
		_water_light = null
	
	if emit_light:
		_create_light()


func _rebuild_light_texture() -> void:
	## Rebuild texture when color changes
	if _water_light:
		_water_light.texture = _create_light_gradient_texture()

## ============================================
## VISUAL UPDATE (per frame)
## ============================================

func _update_visuals() -> void:
	# Determine flare behavior
	# In editor: use the toggle as preview (we can't raycast in editor)
	# At runtime: use _blend_registered (actual pool detection result)
	var should_flare: bool
	if Engine.is_editor_hint():
		should_flare = auto_blend_with_pool
	else:
		should_flare = _blend_registered
	
	if waterfall_size.y <= 0 or segment_count < 2:
		return
	
	var seg_height = waterfall_size.y / (segment_count - 1)
	
	var left_pts: Array[Vector2] = []
	var right_pts: Array[Vector2] = []
	
	# DYNAMIC FLARE: Base + pulsing component for "splash" effect
	var base_flare: float = waterfall_size.x * 0.3 if should_flare else 0.0
	var pulse_flare: float = waterfall_size.x * 0.15 * (0.5 + 0.5 * sin(_wave_time * 3.5)) if should_flare else 0.0
	var flare_width: float = base_flare + pulse_flare
	
	for i in range(segment_count):
		var y = i * seg_height
		var t = float(i) / float(segment_count - 1)  # 0 at top, 1 at bottom
		
		# Wave amplitude increases toward bottom (more turbulent)
		var amp = wave_amplitude * (0.5 + t * 0.5)
		
		# FLUID PHYSICS: At bottom, fall FLARES OUTWARD (not fades!)
		#      I I       <- straight
		#     I   I      <- starts widening  
		#   _/     \_    <- flares where it merges with pool
		var flare_offset: float = 0.0
		if should_flare and t > 0.65:
			# Smooth flare curve: starts earlier (65%), accelerates as it hits
			var flare_t = (t - 0.65) / 0.35  # 0 at 65%, 1 at 100%
			# Cubic acceleration for more dramatic spread at the bottom
			flare_t = flare_t * flare_t * flare_t
			flare_offset = flare_t * flare_width
			# Wave amplitude INCREASES slightly in mid-flare (turbulence), then calms
			if flare_t < 0.5:
				amp *= 1.0 + flare_t * 0.4  # Boost in early flare
			else:
				amp *= 1.2 - (flare_t - 0.5) * 1.4  # Calm as it merges
		
		# Multi-frequency organic waves
		# Subtract flow_offset so waves travel DOWNWARD with the flow
		var phase = _wave_time * wave_speed + (y - _flow_offset) / waterfall_size.y * TAU * 3.0
		var wave_l = sin(phase) * amp + sin(phase * 2.1 + 0.5) * amp * 0.25
		var wave_r = sin(phase + 0.4) * amp + sin(phase * 1.9 + 0.3) * amp * 0.25
		
		# Left edge: normal position is 0, waves go negative (left), flare goes more negative
		left_pts.append(Vector2(-wave_l - flare_offset, y))
		# Right edge: normal position is width, waves go positive (right), flare adds to that
		right_pts.append(Vector2(waterfall_size.x + wave_r + flare_offset, y))
	
	if surface_line_left:
		surface_line_left.points = left_pts
	if surface_line_right:
		surface_line_right.points = right_pts
	
	# Build polygon
	if not fill_polygon:
		return
	
	var poly: PackedVector2Array = []
	match surface_mode:
		SurfaceMode.LEFT_SURFACE:
			for p in left_pts:
				poly.append(p)
			poly.append(Vector2(waterfall_size.x, waterfall_size.y))
			poly.append(Vector2(waterfall_size.x, 0))
		SurfaceMode.RIGHT_SURFACE:
			poly.append(Vector2(0, 0))
			poly.append(Vector2(0, waterfall_size.y))
			for i in range(right_pts.size() - 1, -1, -1):
				poly.append(right_pts[i])
		SurfaceMode.BOTH_SURFACES:
			for p in left_pts:
				poly.append(p)
			for i in range(right_pts.size() - 1, -1, -1):
				poly.append(right_pts[i])
	
	fill_polygon.polygon = poly
	
	# Vertex colors: subtle alpha reduction at bottom when blending
	if should_flare and poly.size() > 0:
		var colors: PackedColorArray = []
		for pt in poly:
			var vert_t = pt.y / waterfall_size.y
			var alpha = water_fill_color.a
			# Only subtle fade at very bottom (90%+)
			if vert_t > 0.90:
				var fade = (vert_t - 0.90) / 0.10
				alpha *= 1.0 - fade * 0.35
			colors.append(Color(water_fill_color.r, water_fill_color.g, water_fill_color.b, alpha))
		fill_polygon.vertex_colors = colors
	else:
		fill_polygon.vertex_colors = PackedColorArray()

## ============================================
## COLLISION CALLBACKS
## ============================================

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("can_interact_with_water") or body.is_in_group("player"):
		if not _bodies_in_water.has(body):
			_bodies_in_water.append(body)
		player_entered_water.emit(body)

func _on_body_exited(body: Node2D) -> void:
	_bodies_in_water.erase(body)
	player_exited_water.emit(body)
