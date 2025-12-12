@tool
extends Node2D
class_name Lavafall
## Vertical lava sheet (lavafall) with viscous animated surfaces
##
## Z-INDEX LAYERING (see scripts/z_layers.gd):
## - Fill polygon: FLUID_FALL_BODY (-3) - behind player
## - Surface lines: FLUID_FALL_SURFACE (7) - in front of player
## - Light effects: LIGHT_EFFECT (20)
## - Particles: EFFECT_FRONT (25)
##
## AUTONOMOUS BLENDING:
## Just place this above a lava pool. That's it.
## - ONE toggle: `auto_blend_with_pool` (default: ON)
## - Automatically detects pool below at runtime
## - Automatically fades bottom edge
## - Automatically tells pool to suppress its surface line
## - INSTANT KILL on contact (matching lava_pool behavior)
##
## USAGE:
## 1. Place lavafall above lava pool
## 2. Done. They blend automatically.

enum SurfaceMode {
	LEFT_SURFACE,   ## Wavy surface on left only (attached to right wall)
	RIGHT_SURFACE,  ## Wavy surface on right only (attached to left wall)
	BOTH_SURFACES   ## Freestanding - both sides are wavy surfaces
}

## === CORE SETTINGS ===
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

## THE MAGIC TOGGLE - just leave it ON
@export var auto_blend_with_pool: bool = true  ## Automatically blend with pool below

@export_group("Visuals")
@export var surface_color: Color = Color(1.0, 0.6, 0.1, 1.0)  ## Bright orange edge
@export var lava_fill_color: Color = Color(0.9, 0.3, 0.05, 0.95)  ## Deep orange-red
@export var surface_line_thickness: float = 3.0  ## Thicker (viscous)
@export_range(8, 48) var segment_count: int = 20  ## Fewer segments (goopy)

@export_group("Wave Animation")
@export var wave_speed: float = 1.0  ## Slower than water (viscous)
@export var wave_amplitude: float = 3.5  ## Wave size
@export var flow_speed: float = 40.0  ## Slow ooze

@export_group("Damage")
@export var instant_kill: bool = true  ## KILL ON CONTACT
@export var damage_per_second: float = 50.0  ## If not instant kill

@export_group("Effects")
@export var emit_light: bool = true  ## Lava glows!
@export var emit_embers: bool = true  ## Rising embers
@export var impact_heat_enabled: bool = true  ## Heat glow at bottom

## === INTERNAL STATE ===
var _wave_time: float = 0.0
var _flow_offset: float = 0.0
var _light_pulse_time: float = 0.0
var _damage_timers: Dictionary = {}
var _detected_pool: Node2D = null
var _blend_registered: bool = false

var surface_line_left: Line2D
var surface_line_right: Line2D
var fill_polygon: Polygon2D
var lava_area: Area2D
var _lava_lights: Array[PointLight2D] = []
var _ember_particles: GPUParticles2D
var _impact_heat: GPUParticles2D

func _ready() -> void:
	_rebuild()
	set_process(true)
	
	# Auto-detect pool below at runtime
	if not Engine.is_editor_hint() and auto_blend_with_pool:
		call_deferred("_auto_blend_setup")

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	
	_damage_timers.clear()
	_lava_lights.clear()
	surface_line_left = null
	surface_line_right = null
	_blend_registered = false
	
	_create_visuals()
	_create_collision()
	
	if emit_light:
		_create_lights()
	
	if emit_embers and not Engine.is_editor_hint():
		_create_embers()
	
	if impact_heat_enabled and not Engine.is_editor_hint():
		_create_impact_heat()
	
	_update_visuals()

func _process(delta: float) -> void:
	_wave_time += delta
	_flow_offset += flow_speed * delta
	if _flow_offset > lavafall_size.y * 2:
		_flow_offset -= lavafall_size.y * 2
	
	# Light pulse
	if _lava_lights.size() > 0:
		_light_pulse_time += delta * 3.0
		var pulse = sin(_light_pulse_time) * 0.15 + 0.85
		for light in _lava_lights:
			if light:
				light.energy = 0.8 * pulse
	
	_update_visuals()
	
	if Engine.is_editor_hint():
		return
	
	# Damage ticks for non-instant-kill mode
	if not instant_kill:
		_update_damage_ticks(delta)

## ============================================
## AUTONOMOUS BLENDING (the magic)
## ============================================

func _auto_blend_setup() -> void:
	var pool = _find_pool_below()
	if not pool:
		return
	
	_detected_pool = pool
	
	var our_left = global_position.x
	var our_right = global_position.x + lavafall_size.x
	var pool_local_left = our_left - pool.global_position.x
	var pool_local_right = our_right - pool.global_position.x
	
	if pool.has_method("_receive_lavafall_blend"):
		pool._receive_lavafall_blend(pool_local_left, pool_local_right, self)
		_blend_registered = true

func _find_pool_below() -> Node2D:
	var space = get_world_2d().direct_space_state
	if not space:
		return null
	
	var from = global_position + Vector2(lavafall_size.x / 2.0, lavafall_size.y)
	var to = from + Vector2(0, 48)
	
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var result = space.intersect_ray(query)
	if result and result.collider:
		var parent = result.collider.get_parent()
		if parent and parent is LavaPool:
			return parent
	
	return null

## ============================================
## VISUAL CREATION
## ============================================

func _create_visuals() -> void:
	if surface_mode == SurfaceMode.LEFT_SURFACE or surface_mode == SurfaceMode.BOTH_SURFACES:
		surface_line_left = _make_surface_line()
		add_child(surface_line_left)
	
	if surface_mode == SurfaceMode.RIGHT_SURFACE or surface_mode == SurfaceMode.BOTH_SURFACES:
		surface_line_right = _make_surface_line()
		add_child(surface_line_right)
	
	fill_polygon = Polygon2D.new()
	fill_polygon.color = lava_fill_color
	fill_polygon.z_index = ZLayers.FLUID_FALL_BODY  # Behind terrain
	add_child(fill_polygon)

func _make_surface_line() -> Line2D:
	var line = Line2D.new()
	line.width = surface_line_thickness
	line.default_color = surface_color
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.z_index = ZLayers.FLUID_FALL_SURFACE  # Behind terrain (visible through gap)
	
	# SEAMLESS BLEND: Edge fades to ZERO at bottom
	# When fall meets pool, NO visible edge = one continuous fluid
	# The edge "becomes" part of the pool's body, not a separate line
	if auto_blend_with_pool:
		var grad = Gradient.new()
		grad.add_point(0.0, surface_color)
		grad.add_point(0.70, surface_color)  # Solid until 70% (lava has bigger flare)
		grad.add_point(0.90, Color(surface_color.r, surface_color.g, surface_color.b, surface_color.a * 0.35))
		grad.add_point(1.0, Color(surface_color.r, surface_color.g, surface_color.b, 0.0))  # ZERO at bottom
		line.gradient = grad
	
	return line

func _create_collision() -> void:
	lava_area = Area2D.new()
	lava_area.name = "LavafallDamage"
	lava_area.monitoring = true
	lava_area.monitorable = false
	lava_area.collision_layer = 0
	lava_area.collision_mask = 2 | 8  # Player + Enemy
	lava_area.body_entered.connect(_on_body_entered)
	lava_area.body_exited.connect(_on_body_exited)
	lava_area.visible = false
	add_child(lava_area)
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = lavafall_size
	shape.shape = rect
	shape.position = lavafall_size / 2.0
	lava_area.add_child(shape)

func _create_lights() -> void:
	# Only 2 lights, positioned in upper portion (away from blend zone)
	for i in range(2):
		var light = PointLight2D.new()
		light.color = Color(1.0, 0.5, 0.1, 1.0)
		light.energy = 0.8
		light.texture_scale = 1.5
		light.blend_mode = Light2D.BLEND_MODE_ADD
		light.z_index = ZLayers.LIGHT_EFFECT
		
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
		
		# Position in upper 50% only
		var y = lavafall_size.y * 0.25 * (1 + i)
		light.position = Vector2(lavafall_size.x / 2.0, y)
		
		add_child(light)
		_lava_lights.append(light)

func _create_embers() -> void:
	_ember_particles = GPUParticles2D.new()
	_ember_particles.position = Vector2(lavafall_size.x / 2.0, lavafall_size.y * 0.3)
	_ember_particles.amount = 6
	_ember_particles.lifetime = 1.5
	_ember_particles.emitting = true
	_ember_particles.z_index = ZLayers.EFFECT_FRONT
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(lavafall_size.x / 2.0, lavafall_size.y * 0.3, 0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 1))
	alpha_curve.add_point(Vector2(0.5, 0.8))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	_ember_particles.process_material = mat
	
	var tex = GradientTexture2D.new()
	tex.width = 8
	tex.height = 8
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 0.5, 0.1, 1))
	grad.set_color(1, Color(1, 0.3, 0.0, 0))
	tex.gradient = grad
	_ember_particles.texture = tex
	
	add_child(_ember_particles)

func _create_impact_heat() -> void:
	_impact_heat = GPUParticles2D.new()
	_impact_heat.position = Vector2(lavafall_size.x / 2.0, lavafall_size.y - 6)
	_impact_heat.amount = 8
	_impact_heat.lifetime = 0.6
	_impact_heat.emitting = true
	_impact_heat.z_index = ZLayers.EFFECT_FRONT
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(lavafall_size.x / 2.0, 6, 0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 25.0
	mat.gravity = Vector3(0, 10, 0)
	mat.scale_min = 4.0
	mat.scale_max = 10.0
	
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 0.5))
	alpha_curve.add_point(Vector2(0.2, 0.8))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	_impact_heat.process_material = mat
	
	var tex = GradientTexture2D.new()
	tex.width = 16
	tex.height = 16
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.6, 0.6))
	grad.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	tex.gradient = grad
	_impact_heat.texture = tex
	
	add_child(_impact_heat)

## ============================================
## VISUAL UPDATE
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
	
	if lavafall_size.y <= 0 or segment_count < 2:
		return
	
	var seg_height = lavafall_size.y / (segment_count - 1)
	
	var left_pts: Array[Vector2] = []
	var right_pts: Array[Vector2] = []
	
	# DYNAMIC FLARE: Base + slower pulsing (lava is viscous, breathes slower)
	var base_flare: float = lavafall_size.x * 0.35 if should_flare else 0.0
	var pulse_flare: float = lavafall_size.x * 0.12 * (0.5 + 0.5 * sin(_wave_time * 2.0)) if should_flare else 0.0
	var flare_width: float = base_flare + pulse_flare
	
	for i in range(segment_count):
		var y = i * seg_height
		var t = float(i) / float(segment_count - 1)  # 0 at top, 1 at bottom
		
		# Wave amplitude increases down the fall (builds momentum)
		var amp = wave_amplitude * (0.6 + t * 0.4)
		
		# FLUID PHYSICS: At bottom, fall FLARES OUTWARD (not fades!)
		#      I I       <- straight
		#     I   I      <- starts widening
		#   _/     \_    <- flares where it merges with pool
		var flare_offset: float = 0.0
		if should_flare and t > 0.65:
			# Smooth flare curve: starts earlier, accelerates as it hits
			var flare_t = (t - 0.65) / 0.35  # 0 at 65%, 1 at 100%
			# Cubic for dramatic effect
			flare_t = flare_t * flare_t * flare_t
			flare_offset = flare_t * flare_width
			# Lava: waves stay strong longer (viscous), then calm
			if flare_t < 0.6:
				amp *= 1.0 + flare_t * 0.3
			else:
				amp *= 1.18 - (flare_t - 0.6) * 1.2
		
		# Slower, goopier waves (lava is viscous)
		var phase = _wave_time * wave_speed + (y + _flow_offset) / lavafall_size.y * TAU * 2.5
		var wave_l = sin(phase) * amp + sin(phase * 1.7 + 0.5) * amp * 0.3
		var wave_r = sin(phase + 0.6) * amp + sin(phase * 1.5 + 0.2) * amp * 0.3
		
		# Left edge: normal position is 0, waves go negative (left), flare goes more negative
		left_pts.append(Vector2(-wave_l - flare_offset, y))
		# Right edge: normal position is width, waves go positive (right), flare adds to that
		right_pts.append(Vector2(lavafall_size.x + wave_r + flare_offset, y))
	
	if surface_line_left:
		surface_line_left.points = left_pts
	if surface_line_right:
		surface_line_right.points = right_pts
	
	if not fill_polygon:
		return
	
	# Build polygon from left and right edges
	var poly: PackedVector2Array = []
	match surface_mode:
		SurfaceMode.LEFT_SURFACE:
			for p in left_pts:
				poly.append(p)
			poly.append(Vector2(lavafall_size.x, lavafall_size.y))
			poly.append(Vector2(lavafall_size.x, 0))
		SurfaceMode.RIGHT_SURFACE:
			poly.append(Vector2(0, 0))
			poly.append(Vector2(0, lavafall_size.y))
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
			var t = pt.y / lavafall_size.y
			var alpha = lava_fill_color.a
			# Only subtle fade at very bottom (92%+)
			if t > 0.92:
				var fade = (t - 0.92) / 0.08
				alpha *= 1.0 - fade * 0.4
			colors.append(Color(lava_fill_color.r, lava_fill_color.g, lava_fill_color.b, alpha))
		fill_polygon.vertex_colors = colors
	else:
		fill_polygon.vertex_colors = PackedColorArray()

## ============================================
## DAMAGE HANDLING
## ============================================

func _on_body_entered(body: Node2D) -> void:
	if instant_kill:
		_kill_body(body)
	else:
		_damage_timers[body] = 0.0

func _on_body_exited(body: Node2D) -> void:
	_damage_timers.erase(body)

func _kill_body(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("die"):
		body.die()
		return
	
	if body.has_method("take_damage"):
		body.take_damage(9999)

func _update_damage_ticks(delta: float) -> void:
	var interval = 0.25
	var to_remove: Array = []
	
	for body in _damage_timers.keys():
		if not is_instance_valid(body):
			to_remove.append(body)
			continue
		
		_damage_timers[body] += delta
		if _damage_timers[body] >= interval:
			_damage_timers[body] -= interval
			var dmg = damage_per_second * interval
			if body.has_method("take_damage"):
				body.take_damage(int(dmg))
	
	for body in to_remove:
		_damage_timers.erase(body)
