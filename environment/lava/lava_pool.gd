@tool
extends Node2D
class_name LavaPool

## Deadly lava pool - glowing orange "water" that kills on contact
## Uses water-like wave physics for fluid surface animation
## Emits light for cave darkness and spawns ember particles
##
## PUZZLE INTEGRATION:
## - drain(duration) - Lowers lava, player can cross
## - fill(duration) - Raises lava back
## - Connect via Channel System (set listen_channel, trigger sets same channel)

signal lava_drained  ## Emitted when drain animation completes
signal lava_filled   ## Emitted when fill animation completes

@export var lava_size: Vector2 = Vector2(128.0, 64.0)
@export var surface_pos_y: float = 0.5
@export_range(2, 256) var segment_count: int = 32

@export_group("Channel System")
## Channel to listen to for lava drain/fill control
## Set same channel on trigger objects (Lever, PressurePlate) to connect them
@export var listen_channel: StringName = &""

@export_group("Drain/Fill Settings")
@export var drain_target_y: float = 60.0  ## Where lava drains to (lower = more visible)
@export var fill_target_y: float = 0.5  ## Where lava fills to (surface level)
@export var default_drain_duration: float = 2.0
@export var default_fill_duration: float = 3.0  ## Slower fill = more tension

@export_group("Visuals")
@export var surface_line_thickness: float = 3.0  ## Thicker glowing edge
@export var surface_color: Color = Color(1.0, 0.6, 0.1, 1.0)  ## Bright orange edge
@export var lava_fill_color: Color = Color(0.9, 0.3, 0.05, 0.95)  ## Deep orange-red
@export var enable_antialiasing: bool = true

@export_group("Glow Light")
@export var emit_light: bool = true  ## Lava glows in darkness
@export var light_color: Color = Color(1.0, 0.5, 0.1, 1.0)  ## Orange glow
@export var light_energy: float = 1.2  ## Brightness
@export var light_sample_points: int = 5  ## Number of light sources along surface (1-8, more = distributed glow)
@export var light_spacing_mode: String = "distributed"  ## "distributed" or "surface_tracking"
@export var light_pulse_enabled: bool = true  ## Flickering glow
@export var light_pulse_speed: float = 3.0
@export var light_pulse_amount: float = 0.3

@export_group("Ambient Waves")
@export var ambient_wave_enabled: bool = true
@export var ambient_wave_amplitude: float = 2.5  ## Lava is more viscous, bigger waves
@export var ambient_wave_speed: float = 0.8  ## Slower than water (thicker)
@export var ambient_wave_length: float = 0.35
@export_range(-1.0, 1.0) var ambient_wave_direction: float = 1.0  ## -1 = left, 0 = standing, 1 = right

@export_group("Physics Simulation")
@export var lava_restoring_force: float = 24.0  ## Spring constant (recalibrated from 0.015×40²)
@export var wave_energy_loss: float = 3.2  ## Linear damping (recalibrated from 0.08×40)
@export var quadratic_damping: float = 3.2  ## Quadratic damping - prevents overshoot
@export var wave_strength: float = 6.0  ## Wave spread (recalibrated from 0.15×40)
@export_range(1, 32) var wave_spread_updates: int = 4

@export_group("Advanced Physics")
@export var rest_zone_damping: float = 0.7  ## Extra damping near rest to kill micro-oscillations
@export var rest_zone_threshold: float = 1.0  ## Displacement threshold for rest-zone damping
@export var emergency_displacement_threshold: float = 50.0  ## Displacement threshold for emergency correction (viscous lava can't reach 150px)

@export_group("Debug")
@export var enable_debug_diagnostics: bool = false  ## Enable lava stability monitoring

@export_group("Ember Particles")
@export var emit_particles: bool = true
@export var particle_count: int = 12
@export var particle_rise_speed: float = 25.0  ## How fast embers float up
@export var particle_lifetime: float = 2.0
@export var particle_spawn_rate: float = 0.3  ## Seconds between spawns

@export_group("Bubble Particles")
@export var emit_bubbles: bool = true
@export var bubble_count: int = 6
@export var bubble_rise_speed: float = 35.0
@export var bubble_spawn_interval: float = 0.6
@export var bubble_min_size: float = 2.0
@export var bubble_max_size: float = 5.0

@export_group("Damage")
@export var instant_kill: bool = true  ## Kill on contact
@export var damage_per_second: float = 50.0  ## If not instant kill, DPS
@export var damage_interval: float = 0.25  ## Damage tick rate

@export_group("Lavafall Blending")
## Just ONE toggle - lavafalls handle everything else automatically
@export var allow_lavafall_blend: bool = true  ## Allow lavafalls to blend into this pool

var segment_data: Array = []
var segment_rest_height: Array = []  ## Per-segment equilibrium height (future: lava geysers/vents)
var _surface_suppression_zones: Array = []  ## Runtime: auto-populated by lavafalls
var _ambient_wave_time: float = 0.0
var _light_pulse_time: float = 0.0
var _damage_timers: Dictionary = {}  ## Per-body damage cooldown

## Performance optimization: track settled segments to skip physics
var _settled_segments: PackedByteArray = []  ## 0 = needs update, 1 = at rest
var _settled_count: int = 0
var _last_active_min: int = 0
var _last_active_max: int = 0

## Debug monitoring
var debug_timer: float = 0.0
var debug_interval: float = 1.0

var surface_line: Line2D
var fill_polygon: Polygon2D
var lava_area: Area2D
var lava_lights: Array[PointLight2D] = []  ## Multiple light sources for distributed glow
var ember_gpu_particles: GPUParticles2D
var bubble_gpu_particles: GPUParticles2D

## ==========================================
## AUTONOMOUS LAVAFALL BLEND RECEIVER
## Lavafalls call this automatically - you don't need to do anything!
## ==========================================

## Called by Lavafall when it detects this pool below it
func _receive_lavafall_blend(x_min: float, x_max: float, lavafall: Node2D) -> void:
	if not allow_lavafall_blend:
		return
	
	# 1. Surface line suppression (subtle fade, not invisible)
	_surface_suppression_zones.append({
		"x_min": x_min,
		"x_max": x_max,
		"fade_width": 10.0
	})
	_rebuild_surface_gradient()
	
	# 2. PHYSICS: Depress the pool surface where fall impacts
	#    Real fluid: falling column pushes surface down, curves away at edges
	#    This creates the "dip" that matches the lavafall's flare
	_apply_lavafall_depression(x_min, x_max)
	
	# 3. CONTINUOUS BUBBLING: Store impact zone for ongoing disturbance
	#    Real lava: constant bubbling/roiling from falling lava
	_lavafall_impact_zones.append({
		"x_min": x_min,
		"x_max": x_max,
		"lavafall": lavafall,
		"last_bubble_time": 0.0
	})

## Track lavafall impact zones for continuous bubbling
var _lavafall_impact_zones: Array = []

## Apply a permanent surface depression where lavafall impacts
## The falling lava pushes the surface down - edges curve up smoothly
func _apply_lavafall_depression(x_min: float, x_max: float) -> void:
	if segment_rest_height.is_empty():
		return
	
	var seg_width = lava_size.x / float(segment_count - 1)
	var depression_depth: float = 5.0  # Lava is heavier, deeper depression
	var edge_fade: float = 18.0  # Wider smooth transition (viscous)
	
	for i in range(segment_count):
		var seg_x = i * seg_width
		
		# Calculate distance from impact zone
		var dist_from_center: float = 0.0
		if seg_x < x_min:
			dist_from_center = x_min - seg_x
		elif seg_x > x_max:
			dist_from_center = seg_x - x_max
		else:
			dist_from_center = 0.0  # Inside impact zone
		
		# Inside the impact zone: full depression
		# Near edges: smooth fade using smoothstep
		var depression: float = 0.0
		if dist_from_center <= 0.0:
			# Inside: full depression
			depression = depression_depth
		elif dist_from_center < edge_fade:
			# Edge fade: smooth curve up
			var t = dist_from_center / edge_fade
			t = 1.0 - (t * t * (3.0 - 2.0 * t))  # inverse smoothstep
			depression = t * depression_depth
		
		# Apply depression (raise the rest height = lower the surface visually)
		if depression > 0.0:
			segment_rest_height[i] += depression

## Called every physics frame to apply continuous lavafall bubbling
func _apply_lavafall_bubbles(time: float) -> void:
	if _lavafall_impact_zones.is_empty():
		return
	
	var seg_width = lava_size.x / float(segment_count - 1)
	var bubble_interval: float = 0.25  # Slower than water (viscous lava)
	var bubble_strength: float = 2.0  # Bigger bubbles (dense fluid)
	
	for zone in _lavafall_impact_zones:
		if not is_instance_valid(zone["lavafall"]):
			continue
		
		# Check if it's time for another bubble
		if time - zone["last_bubble_time"] >= bubble_interval:
			zone["last_bubble_time"] = time
			
			# Pick a random segment within the impact zone
			var zone_center_x = (zone["x_min"] + zone["x_max"]) / 2.0
			var zone_width = zone["x_max"] - zone["x_min"]
			var random_x = zone_center_x + (randf() - 0.5) * zone_width
			var seg_idx = int(random_x / seg_width)
			seg_idx = clamp(seg_idx, 0, segment_count - 1)
			
			# Apply upward impulse (lava bubble popping)
			if seg_idx < segment_data.size():
				segment_data[seg_idx]["velocity"] -= bubble_strength * (0.7 + randf() * 0.6)
				_settled_segments[seg_idx] = 0  # Mark as active

## Rebuild the Line2D gradient based on suppression zones (internal)
func _rebuild_surface_gradient() -> void:
	if not surface_line or _surface_suppression_zones.is_empty():
		if surface_line:
			surface_line.gradient = null
		return
	
	var grad = Gradient.new()
	var stops: Array = []
	stops.append({"offset": 0.0, "color": surface_color})
	
	for zone in _surface_suppression_zones:
		var x_min = zone["x_min"]
		var x_max = zone["x_max"]
		var fade = zone["fade_width"]
		
		var t_fade_start = clamp((x_min - fade) / lava_size.x, 0.0, 1.0)
		var t_zone_start = clamp(x_min / lava_size.x, 0.0, 1.0)
		var t_zone_end = clamp(x_max / lava_size.x, 0.0, 1.0)
		var t_fade_end = clamp((x_max + fade) / lava_size.x, 0.0, 1.0)
		
		if t_fade_start > 0.01:
			stops.append({"offset": t_fade_start, "color": surface_color})
		stops.append({"offset": t_zone_start, "color": Color(surface_color.r, surface_color.g, surface_color.b, 0.0)})
		stops.append({"offset": t_zone_end, "color": Color(surface_color.r, surface_color.g, surface_color.b, 0.0)})
		if t_fade_end < 0.99:
			stops.append({"offset": t_fade_end, "color": surface_color})
	
	stops.append({"offset": 1.0, "color": surface_color})
	stops.sort_custom(func(a, b): return a["offset"] < b["offset"])
	
	grad.offsets = PackedFloat32Array()
	grad.colors = PackedColorArray()
	var last_offset = -1.0
	for stop in stops:
		if stop["offset"] > last_offset + 0.001:
			grad.add_point(stop["offset"], stop["color"])
			last_offset = stop["offset"]
	
	surface_line.gradient = grad

@export_tool_button("Update Lava") var update_lava_button: Callable = func():
	_ready()
	_update_visuals()

func _ready() -> void:
	# Clean up existing children
	for child in get_children():
		child.queue_free()
	
	segment_data.clear()
	segment_rest_height.clear()
	_settled_segments.clear()
	_damage_timers.clear()
	
	_initiate_lava()
	
	if emit_light:
		_setup_light()
	
	# Setup GPU particles
	if not Engine.is_editor_hint():
		if emit_particles:
			_setup_ember_gpu_particles()
		if emit_bubbles:
			_setup_bubble_gpu_particles()
	
	# Always enable processing for visuals (editor + runtime)
	set_process(true)
	
	# Runtime-only: subscribe to channel system
	if not Engine.is_editor_hint():
		if not listen_channel.is_empty():
			var channel_manager = get_node_or_null("/root/InteractionChannel")
			if channel_manager:
				channel_manager.channel_activated.connect(_on_channel_activated)
				channel_manager.channel_deactivated.connect(_on_channel_deactivated)


func _on_channel_activated(channel: StringName, _source: Node) -> void:
	if channel != listen_channel:
		return
	# Channel activated = drain lava (safe to cross)
	drain()


func _on_channel_deactivated(channel: StringName, _source: Node) -> void:
	if channel != listen_channel:
		return
	# Channel deactivated = fill lava (danger!)
	fill()


func _process(delta: float) -> void:
	# Ambient wave animation (runs in BOTH editor and runtime for visual life)
	if ambient_wave_enabled:
		_ambient_wave_time += delta
	
	# EDITOR MODE: Only update visuals (no physics, particles, or gameplay)
	if Engine.is_editor_hint():
		_update_visuals()
		return
	
	# Debug diagnostics
	if enable_debug_diagnostics:
		debug_timer += delta
		if debug_timer >= debug_interval:
			_print_lava_diagnostics()
			debug_timer = 0.0
	
	# Drain/fill animation
	if _drain_active:
		_update_drain_fill(delta)
	
	# Light pulsing
	if light_pulse_enabled and lava_lights.size() > 0:
		_update_light_pulse(delta)
	
	# Continuous lavafall bubbling (creates "damn that's smooth" effect)
	_apply_lavafall_bubbles(_ambient_wave_time)
	
	# Wave physics (KEEP - this is gameplay interaction)
	_update_physics(delta)
	_update_visuals()
	
	# Update light/particle positions to track surface (dynamic positioning)
	if lava_lights.size() > 0 and not _drain_active:
		# Each light tracks local segment height for distributed glow
		for i in range(lava_lights.size()):
			var light = lava_lights[i]
			if not light:
				continue
			
			# Calculate which segments this light should track
			var segment_start = int(float(i) / lava_lights.size() * segment_count)
			var segment_end = int(float(i + 1) / lava_lights.size() * segment_count)
			segment_end = min(segment_end, segment_count - 1)
			
			# Average height of tracked segments
			var local_height = 0.0
			var count = 0
			for seg_idx in range(segment_start, segment_end + 1):
				local_height += segment_data[seg_idx]["height"]
				count += 1
			local_height /= count if count > 0 else 1
			
			light.position.y = local_height
	
	if ember_gpu_particles and not _drain_active:
		var avg_height = 0.0
		for i in range(segment_count):
			avg_height += segment_data[i]["height"]
		avg_height /= segment_count
		ember_gpu_particles.position.y = avg_height
		# Enable particles only when lava is active
		ember_gpu_particles.emitting = not (_drain_active and _is_draining)
	
	if bubble_gpu_particles and not _drain_active:
		var avg_height = 0.0
		for i in range(segment_count):
			avg_height += segment_data[i]["height"]
		avg_height /= segment_count
		bubble_gpu_particles.position.y = avg_height + 10
		# Enable particles only when lava is active
		bubble_gpu_particles.emitting = not (_drain_active and _is_draining)

func _initiate_lava() -> void:
	# Initialize segment data
	for i in range(segment_count):
		segment_data.append({
			"height": surface_pos_y,
			"velocity": 0.0
		})
		segment_rest_height.append(surface_pos_y)  # Default: all segments rest at surface
		_settled_segments.append(1)  # Start at rest
	_settled_count = segment_count
	_last_active_min = 0
	_last_active_max = segment_count - 1
	
	# Create surface line
	surface_line = Line2D.new()
	surface_line.width = surface_line_thickness
	surface_line.default_color = surface_color
	surface_line.antialiased = enable_antialiasing
	surface_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	surface_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	surface_line.joint_mode = Line2D.LINE_JOINT_ROUND
	surface_line.z_as_relative = false  # Use absolute z_index
	surface_line.z_index = ZLayers.FLUID_SURFACE  # IN FRONT of player (rippling top edge)
	add_child(surface_line)
	
	# Create fill polygon
	fill_polygon = Polygon2D.new()
	fill_polygon.color = lava_fill_color
	fill_polygon.z_as_relative = false  # Use absolute z_index
	fill_polygon.z_index = ZLayers.FLUID_BODY  # IN FRONT of player (semi-transparent submersion)
	add_child(fill_polygon)  # Add directly, not to line
	
	# Create damage area
	lava_area = Area2D.new()
	lava_area.name = "LavaDamageArea"
	lava_area.monitoring = true
	lava_area.monitorable = false
	lava_area.collision_layer = 0
	lava_area.collision_mask = 2 | 8  # Player body (2) + Enemy body (8)
	lava_area.body_entered.connect(_on_body_entered)
	lava_area.body_exited.connect(_on_body_exited)
	add_child(lava_area)
	
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = lava_size
	collision_shape.shape = rect_shape
	collision_shape.position = Vector2(lava_size.x / 2.0, surface_pos_y + (lava_size.y - surface_pos_y) / 2.0)
	lava_area.add_child(collision_shape)

func _setup_light() -> void:
	# Create multiple point lights along lava surface for distributed glow
	var num_lights = clamp(light_sample_points, 1, 8)
	lava_lights.clear()
	
	for i in range(num_lights):
		var light = PointLight2D.new()
		light.name = "LavaGlow_%d" % i
		light.color = light_color
		light.energy = light_energy / float(num_lights) * 1.5  # Distribute energy, slight boost
		light.texture_scale = 2.0  # Radius per light
		light.shadow_enabled = false  # Shadows only on first light to save performance
		light.z_index = ZLayers.LIGHT_EFFECT
		light.blend_mode = Light2D.BLEND_MODE_ADD  # Additive blend for overlapping glows
		
		# Create radial gradient texture (shared across lights for efficiency)
		if i == 0:
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
			light.shadow_enabled = true  # Only first light casts shadows
		else:
			# Reuse texture from first light
			light.texture = lava_lights[0].texture
		
		# Position evenly along lava width
		var x_pos = lava_size.x * (float(i) / float(num_lights - 1 if num_lights > 1 else 1))
		light.position = Vector2(x_pos, surface_pos_y)
		
		add_child(light)
		lava_lights.append(light)

func _setup_ember_gpu_particles() -> void:
	ember_gpu_particles = GPUParticles2D.new()
	ember_gpu_particles.name = "LavaEmbers"
	ember_gpu_particles.position = Vector2(lava_size.x / 2.0, surface_pos_y)
	ember_gpu_particles.amount = particle_count
	ember_gpu_particles.lifetime = particle_lifetime
	ember_gpu_particles.randomness = 0.5
	ember_gpu_particles.emitting = true
	ember_gpu_particles.z_index = ZLayers.EFFECT_FRONT  # Embers above lava
	
	# Configure particle material
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(lava_size.x / 2.0, 2, 0)
	mat.direction = Vector3(0, -1, 0)  # Upward
	mat.spread = 10.0
	mat.initial_velocity_min = particle_rise_speed * 0.8
	mat.initial_velocity_max = particle_rise_speed * 1.2
	mat.gravity = Vector3(0, -particle_rise_speed * 0.3, 0)
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
	
	ember_gpu_particles.process_material = mat
	
	# Create ember texture
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
	ember_gpu_particles.texture = ember_tex
	
	add_child(ember_gpu_particles)

func _setup_bubble_gpu_particles() -> void:
	bubble_gpu_particles = GPUParticles2D.new()
	bubble_gpu_particles.name = "LavaBubbles"
	bubble_gpu_particles.position = Vector2(lava_size.x / 2.0, surface_pos_y + 10)
	bubble_gpu_particles.amount = bubble_count
	bubble_gpu_particles.lifetime = bubble_spawn_interval * bubble_count
	bubble_gpu_particles.randomness = 0.6
	bubble_gpu_particles.emitting = true
	bubble_gpu_particles.z_index = ZLayers.EFFECT_FRONT  # Bubbles above lava
	
	# Configure particle material
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(lava_size.x / 2.0, 5, 0)
	mat.direction = Vector3(0, -1, 0)  # Upward
	mat.spread = 5.0
	mat.initial_velocity_min = bubble_rise_speed * 0.8
	mat.initial_velocity_max = bubble_rise_speed * 1.2
	mat.gravity = Vector3(0, -bubble_rise_speed * 0.2, 0)
	mat.scale_min = bubble_min_size
	mat.scale_max = bubble_max_size
	
	# Pop at end
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 0.6))
	alpha_curve.add_point(Vector2(0.9, 0.5))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	bubble_gpu_particles.process_material = mat
	
	# Create bubble texture (darker orange circle)
	var bubble_tex = GradientTexture2D.new()
	bubble_tex.width = 12
	bubble_tex.height = 12
	bubble_tex.fill = GradientTexture2D.FILL_RADIAL
	bubble_tex.fill_from = Vector2(0.5, 0.5)
	bubble_tex.fill_to = Vector2(0.5, 0.0)
	var bubble_grad = Gradient.new()
	bubble_grad.set_color(0, Color(0.8, 0.3, 0.05, 0.6))
	bubble_grad.set_color(1, Color(0.7, 0.2, 0.0, 0))
	bubble_tex.gradient = bubble_grad
	bubble_gpu_particles.texture = bubble_tex
	
	add_child(bubble_gpu_particles)

func _update_light_pulse(delta: float) -> void:
	_light_pulse_time += delta * light_pulse_speed
	
	# Flickering effect using multiple sine waves for organic feel
	var flicker = sin(_light_pulse_time) * 0.5 + 0.5
	flicker += sin(_light_pulse_time * 2.3) * 0.3
	flicker += sin(_light_pulse_time * 0.7) * 0.2
	flicker = clamp(flicker / 2.0, 0.0, 1.0)
	
	# Apply to all lights
	for light in lava_lights:
		if light:
			light.energy = (light_energy / float(lava_lights.size()) * 1.5) + (flicker * light_pulse_amount)

func _update_physics(delta: float) -> void:
	# CRITICAL: Validate delta to prevent catastrophic physics behavior
	if not is_finite(delta) or delta <= 0.0 or delta > 1.0:
		push_warning("Lava physics: invalid delta %.3f, skipping frame" % delta)
		return
	
	var safe_delta = min(delta, 0.05)  # Cap at 20 FPS worst case
	
	# Lag compensation: if actual delta is larger than safe_delta, add extra damping
	var lag_damping_factor = 1.0
	if delta > 0.03:  # FPS below 33
		var lag_severity = (delta - 0.03) / 0.03
		lag_damping_factor = 1.0 + (lag_severity * lag_severity * 0.5)
	
	# OPTIMIZATION: Track active region to skip settled segments
	var active_min = segment_count
	var active_max = -1
	
	# CRITICAL: Reset settled count each frame and recalculate from scratch
	_settled_count = 0
	
	# Expand search window around last active region
	var search_min = max(0, _last_active_min - 2)
	var search_max = min(segment_count - 1, _last_active_max + 2)
	
	# Process segments (only check potentially active ones)
	for i in range(search_min, search_max + 1):
		# Skip if marked as settled
		if _settled_segments[i] == 1:
			_settled_count += 1
			continue
		
		var seg = segment_data[i]
		var rest = segment_rest_height[i]
		var displacement = seg["height"] - rest
		
		# Emergency displacement: prevent total runaway
		if abs(displacement) > emergency_displacement_threshold:
			var emergency_correction = -sign(displacement) * abs(displacement) * 0.5
			seg["height"] += emergency_correction * safe_delta
			seg["velocity"] *= 0.5
			active_min = min(active_min, i)
			active_max = max(active_max, i)
			continue
		
		var velocity = seg["velocity"]
		
		# OPTIMIZATION: Check if segment has settled (before expensive math)
		# Note: velocity threshold accounts for lava_physics_speed inflation
		if abs(displacement) < 0.3 and abs(velocity) < 1.2:
			_settled_segments[i] = 1
			_settled_count += 1
			seg["velocity"] = 0.0
			seg["height"] = rest  # Snap to rest
			continue
		
		# Mark as active
		active_min = min(active_min, i)
		active_max = max(active_max, i)
		
		# Physics integration (direct, no artificial time multiplier)
		var spring_force = -lava_restoring_force * displacement
		var linear_damping = wave_energy_loss * lag_damping_factor * velocity
		var quadratic_damping_force = quadratic_damping * velocity * abs(velocity)
		var acceleration = spring_force - linear_damping - quadratic_damping_force
		
		# Velocity integration
		seg["velocity"] += acceleration * safe_delta
		
		# REST-ZONE DAMPING: Kill micro-oscillations near rest
		if abs(displacement) < rest_zone_threshold and abs(seg["velocity"]) < 5.0:
			seg["velocity"] *= rest_zone_damping
		
		# Dynamic velocity clamp (based on displacement magnitude)
		var max_velocity = 8.0 + abs(displacement) * 1.5
		seg["velocity"] = clamp(seg["velocity"], -max_velocity, max_velocity)
		
		# Position integration
		seg["height"] += seg["velocity"] * safe_delta
	
	# Update active region tracking
	if active_min < segment_count:
		_last_active_min = active_min
		_last_active_max = active_max
	
	# OPTIMIZATION: Skip wave propagation if no active segments
	if active_min >= segment_count:
		return
	
	# Wave propagation (only in active region)
	var actual_spread_updates = wave_spread_updates
	if delta > 0.025:
		actual_spread_updates = max(2, wave_spread_updates / 2)
	
	for _update in range(actual_spread_updates):
		for i in range(max(1, active_min), min(segment_count - 1, active_max + 1)):
			var seg = segment_data[i]
			var rest = segment_rest_height[i]
			var i_displacement = abs(seg["height"] - rest)
			var i_velocity = abs(seg["velocity"])
			
			# Skip settled or emergency segments
			if i_displacement > emergency_displacement_threshold or (i_displacement < 0.5 and i_velocity < 1.0):
				continue
			
			# Left neighbor
			if i > 0:
				var left_seg = segment_data[i - 1]
				var left_diff = seg["height"] - left_seg["height"]
				var wave_force = left_diff * wave_strength
				left_seg["velocity"] += wave_force * safe_delta
				
				# Wake up left neighbor if significant force applied
				if abs(wave_force) > 2.0 and _settled_segments[i - 1] == 1:
					_settled_segments[i - 1] = 0
			
			# Right neighbor
			if i < segment_count - 1:
				var right_seg = segment_data[i + 1]
				var right_diff = seg["height"] - right_seg["height"]
				var wave_force = right_diff * wave_strength
				right_seg["velocity"] += wave_force * safe_delta
				
				# Wake up right neighbor if significant force applied
				if abs(wave_force) > 2.0 and _settled_segments[i + 1] == 1:
					_settled_segments[i + 1] = 0
	
	# Edge segments: smooth convergence
	var edge_convergence_strength = 2.0
	for edge_idx in [0, 1, segment_count - 2, segment_count - 1]:
		var seg = segment_data[edge_idx]
		var rest = segment_rest_height[edge_idx]
		var displacement_from_rest = rest - seg["height"]
		var correction_force = displacement_from_rest * edge_convergence_strength * safe_delta
		seg["velocity"] += correction_force
		seg["velocity"] = clamp(seg["velocity"], -10.0, 10.0)

func _update_visuals() -> void:
	var points: Array[Vector2] = []
	var segment_width = lava_size.x / (segment_count - 1)
	
	for i in range(segment_count):
		var base_height = segment_data[i]["height"]
		
		# Add ambient wave offset
		var ambient_offset = 0.0
		if ambient_wave_enabled:
			# direction: -1 = waves travel left, 0 = standing wave, 1 = waves travel right
			var direction = ambient_wave_direction if ambient_wave_direction != null else 1.0
			var position_term = (float(i) / segment_count) * TAU / ambient_wave_length
			var wave_phase = _ambient_wave_time * ambient_wave_speed - position_term * direction
			ambient_offset = sin(wave_phase) * ambient_wave_amplitude
		
		points.append(Vector2(i * segment_width, base_height + ambient_offset))
	
	# Build surface line
	var final_points: Array[Vector2] = []
	final_points.append(points[0])
	final_points += points
	final_points.append(points[points.size() - 1])
	surface_line.points = final_points
	
	# Build fill polygon
	var bottom_y = lava_size.y
	final_points.append(Vector2(lava_size.x, bottom_y))
	final_points.append(Vector2(0, bottom_y))
	fill_polygon.polygon = final_points

func _on_body_entered(body: Node2D) -> void:
	# Create splash effect for visual feedback
	if body.has_method("get_velocity"):
		var vel = body.get_velocity() if body.has_method("get_velocity") else body.velocity if "velocity" in body else Vector2.ZERO
		splash(body.global_position, -vel.y * 0.3)
	
	if instant_kill:
		_kill_body(body)
	else:
		# Start damage over time
		_damage_timers[body] = 0.0
		_apply_damage(body)

func _on_body_exited(body: Node2D) -> void:
	_damage_timers.erase(body)

func _kill_body(body: Node2D) -> void:
	# Player-specific kill (die method)
	if body.is_in_group("player"):
		if body.has_method("die"):
			body.die()
		return
	
	# Enemy-specific kill (take_damage with massive damage)
	if body.has_method("take_damage"):
		# Enemies use take_damage, not die
		if body.has_method("get_max_health"):  # Has health system
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

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# Process damage ticks for bodies in lava
	var bodies_to_remove: Array = []
	for body in _damage_timers.keys():
		if not is_instance_valid(body):
			bodies_to_remove.append(body)
			continue
		
		_damage_timers[body] += delta
		if _damage_timers[body] >= damage_interval:
			_damage_timers[body] = 0.0
			_apply_damage(body)
	
	for body in bodies_to_remove:
		_damage_timers.erase(body)

## Create splash effect when something falls in
func splash(splash_pos: Vector2, splash_velocity: float) -> void:
	var local_x = to_local(splash_pos).x
	var segment_width = lava_size.x / (segment_count - 1)
	var index = int(clamp(local_x / segment_width, 0, segment_count - 1))
	
	# Lava splashes are smaller (more viscous)
	segment_data[index]["velocity"] += splash_velocity * 0.5
	
	# Wake up segment and neighbors
	_settled_segments[index] = 0
	if index > 0:
		_settled_segments[index - 1] = 0
	if index < segment_count - 1:
		_settled_segments[index + 1] = 0

## ============================================================================
## BUBBLE SYSTEM
## ============================================================================
## DRAIN/FILL SYSTEM
## For puzzle integration - lever controls lava level
## ============================================================================

var _drain_active: bool = false
var _drain_start_y: float = 0.0
var _drain_target_y: float = 0.0
var _drain_duration: float = 0.0
var _drain_elapsed: float = 0.0
var _is_draining: bool = true  ## true = draining down, false = filling up

func drain(duration: float = -1.0) -> void:
	## Lower lava level - player can cross safely
	## @param duration: Transition time in seconds (-1 = use default)
	if duration < 0:
		duration = default_drain_duration
	
	_drain_start_y = surface_pos_y
	_drain_target_y = drain_target_y
	_drain_duration = duration
	_drain_elapsed = 0.0
	_drain_active = true
	_is_draining = true
	
	# Disable collision during drain (safe to cross)
	_set_damage_enabled(false)
	
	set_process(true)

func fill(duration: float = -1.0) -> void:
	## Raise lava level back up - danger returns!
	## @param duration: Transition time in seconds (-1 = use default)
	if duration < 0:
		duration = default_fill_duration
	
	_drain_start_y = surface_pos_y
	_drain_target_y = fill_target_y
	_drain_duration = duration
	_drain_elapsed = 0.0
	_drain_active = true
	_is_draining = false
	
	set_process(true)

func _update_drain_fill(delta: float) -> void:
	if not _drain_active:
		return
	
	_drain_elapsed += delta
	var progress = clamp(_drain_elapsed / _drain_duration, 0.0, 1.0)
	
	# Smooth easing
	var eased = progress * progress * (3.0 - 2.0 * progress)
	
	# Interpolate surface position
	surface_pos_y = lerp(_drain_start_y, _drain_target_y, eased)
	
	# Update all segment heights and rest heights to follow
	for i in range(segment_count):
		segment_data[i]["height"] = surface_pos_y
		segment_rest_height[i] = surface_pos_y
		_settled_segments[i] = 1  # Mark as settled after forced movement
	_settled_count = segment_count
	_last_active_min = 0
	_last_active_max = segment_count - 1
	
	# Update collision shape position AND size
	if lava_area:
		var collision = lava_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision and collision.shape is RectangleShape2D:
			var shape = collision.shape as RectangleShape2D
			var new_height = lava_size.y - surface_pos_y
			shape.size = Vector2(lava_size.x, new_height)
			collision.position = Vector2(lava_size.x / 2.0, surface_pos_y + new_height / 2.0)
	
	# Update light and particle positions during animation
	if lava_lights.size() > 0:
		for light in lava_lights:
			if light:
				light.position.y = surface_pos_y
				# Dim lights when draining (fade out effect)
				if _is_draining:
					light.energy = (light_energy / float(lava_lights.size()) * 1.5) * (1.0 - progress)
	if ember_gpu_particles:
		ember_gpu_particles.position.y = surface_pos_y
		ember_gpu_particles.emitting = not _is_draining  # Stop emitting when draining
	if bubble_gpu_particles:
		bubble_gpu_particles.position.y = surface_pos_y + 10
		bubble_gpu_particles.emitting = not _is_draining
	
	if progress >= 1.0:
		_drain_active = false
		
		if _is_draining:
			lava_drained.emit()
		else:
			# Re-enable damage when filled
			_set_damage_enabled(true)
			# Restore light energy after fill
			for light in lava_lights:
				if light:
					light.energy = light_energy / float(lava_lights.size()) * 1.5
			# Re-enable particles after fill
			if ember_gpu_particles:
				ember_gpu_particles.emitting = true
			if bubble_gpu_particles:
				bubble_gpu_particles.emitting = true
			lava_filled.emit()

func _set_damage_enabled(enabled: bool) -> void:
	## Enable/disable lava damage (used during drain)
	if lava_area:
		lava_area.monitoring = enabled
		# Also clear any pending damage
		if not enabled:
			_damage_timers.clear()

func is_drained() -> bool:
	## Check if lava is currently drained (safe to cross)
	return surface_pos_y >= drain_target_y - 5.0

func is_filled() -> bool:
	## Check if lava is at full level (dangerous)
	return surface_pos_y <= fill_target_y + 5.0

## ============================================================================
## DEBUG DIAGNOSTICS
## ============================================================================

func _print_lava_diagnostics() -> void:
	## Print lava health metrics for debugging
	var max_displacement = 0.0
	var max_velocity = 0.0
	var avg_displacement = 0.0
	var avg_velocity = 0.0
	
	for i in range(segment_count):
		var displacement = abs(segment_data[i]["height"] - segment_rest_height[i])
		var velocity = abs(segment_data[i]["velocity"])
		max_displacement = max(max_displacement, displacement)
		max_velocity = max(max_velocity, velocity)
		avg_displacement += displacement
		avg_velocity += velocity
	
	avg_displacement /= segment_count
	avg_velocity /= segment_count
	
	# Sanity check: recalculate settled count if it seems corrupted
	var recalc_settled = 0
	for i in range(segment_count):
		if _settled_segments[i] == 1:
			recalc_settled += 1
	
	var settled_mismatch = ""
	if recalc_settled != _settled_count:
		settled_mismatch = " [MISMATCH! Recalc=%d]" % recalc_settled
		_settled_count = recalc_settled  # Auto-fix
	
	print("[LAVA AUDIT] Settled: %d/%d%s | Active region: [%d, %d] | Max disp: %.2f | Max vel: %.2f | Avg disp: %.2f | Avg vel: %.2f" % [
		_settled_count, segment_count, settled_mismatch,
		_last_active_min, _last_active_max,
		max_displacement, max_velocity,
		avg_displacement, avg_velocity
	])
