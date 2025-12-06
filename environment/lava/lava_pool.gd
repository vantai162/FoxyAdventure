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
## - Connect to Lever with LAVA_LEVEL target type

signal lava_drained  ## Emitted when drain animation completes
signal lava_filled   ## Emitted when fill animation completes

@export var lava_size: Vector2 = Vector2(128.0, 64.0)
@export var surface_pos_y: float = 0.5
@export_range(2, 256) var segment_count: int = 32

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
@export var light_radius: float = 150.0  ## How far light reaches
@export var light_pulse_enabled: bool = true  ## Flickering glow
@export var light_pulse_speed: float = 3.0
@export var light_pulse_amount: float = 0.3

@export_group("Ambient Waves")
@export var ambient_wave_enabled: bool = true
@export var ambient_wave_amplitude: float = 2.5  ## Lava is more viscous, bigger waves
@export var ambient_wave_speed: float = 0.8  ## Slower than water (thicker)
@export var ambient_wave_length: float = 0.35

@export_group("Physics Simulation")
@export_range(0.0, 500.0) var lava_physics_speed: float = 40.0  ## Slower, more viscous
@export var lava_restoring_force: float = 0.015  ## Weaker spring (thicker fluid)
@export var wave_energy_loss: float = 0.08  ## More damping (viscous)
@export var wave_strength: float = 0.15  ## Weaker wave spread
@export_range(1, 32) var wave_spread_updates: int = 4

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

var segment_data: Array = []
var _ambient_wave_time: float = 0.0
var _light_pulse_time: float = 0.0
var _particle_timer: float = 0.0
var _damage_timers: Dictionary = {}  ## Per-body damage cooldown

var surface_line: Line2D
var fill_polygon: Polygon2D
var lava_area: Area2D
var lava_light: PointLight2D
var ember_particles: Array[Node2D] = []
var bubble_particles: Array[Node2D] = []
var _bubble_timer: float = 0.0

@export_tool_button("Update Lava") var update_lava_button: Callable = func():
	_ready()

func _ready() -> void:
	# Clean up existing children
	for child in get_children():
		child.queue_free()
	
	segment_data.clear()
	ember_particles.clear()
	bubble_particles.clear()
	_damage_timers.clear()
	
	_initiate_lava()
	
	if emit_light:
		_setup_light()
	
	if not Engine.is_editor_hint():
		set_process(true)

func _process(delta: float) -> void:
	# Drain/fill animation
	if _drain_active:
		_update_drain_fill(delta)
	
	# Ambient wave animation
	if ambient_wave_enabled:
		_ambient_wave_time += delta
	
	# Light pulsing
	if light_pulse_enabled and lava_light:
		_update_light_pulse(delta)
	
	# Ember particles
	if emit_particles and not Engine.is_editor_hint():
		_update_particles(delta)
	
	# Bubble particles
	if emit_bubbles and not Engine.is_editor_hint():
		_update_bubbles(delta)
	
	_update_physics(delta)
	_update_visuals()

func _initiate_lava() -> void:
	# Initialize segment data
	for i in range(segment_count):
		segment_data.append({
			"height": surface_pos_y,
			"velocity": 0.0
		})
	
	# Create surface line
	surface_line = Line2D.new()
	surface_line.width = surface_line_thickness
	surface_line.default_color = surface_color
	surface_line.antialiased = enable_antialiasing
	surface_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	surface_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	surface_line.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(surface_line)
	
	# Create fill polygon
	fill_polygon = Polygon2D.new()
	fill_polygon.color = lava_fill_color
	surface_line.add_child(fill_polygon)
	
	# Create damage area
	lava_area = Area2D.new()
	lava_area.name = "LavaDamageArea"
	lava_area.monitoring = true
	lava_area.monitorable = false
	lava_area.collision_layer = 0
	lava_area.collision_mask = 2 | 4  # Player (2) and enemies (4)
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
	lava_light = PointLight2D.new()
	lava_light.name = "LavaGlow"
	lava_light.color = light_color
	lava_light.energy = light_energy
	lava_light.texture_scale = light_radius / 128.0
	lava_light.shadow_enabled = true  # Cast shadows from walls
	
	# Position light at center of lava surface
	lava_light.position = Vector2(lava_size.x / 2.0, surface_pos_y)
	
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
	lava_light.texture = gradient
	
	add_child(lava_light)

func _update_light_pulse(delta: float) -> void:
	_light_pulse_time += delta * light_pulse_speed
	
	# Flickering effect using multiple sine waves for organic feel
	var flicker = sin(_light_pulse_time) * 0.5 + 0.5
	flicker += sin(_light_pulse_time * 2.3) * 0.3
	flicker += sin(_light_pulse_time * 0.7) * 0.2
	flicker = clamp(flicker / 2.0, 0.0, 1.0)
	
	lava_light.energy = light_energy + (flicker * light_pulse_amount)

func _update_physics(delta: float) -> void:
	var safe_delta = min(delta, 0.05)
	
	for i in range(segment_count):
		var displacement = segment_data[i]["height"] - surface_pos_y
		
		# Spring force back to rest
		var damping = wave_energy_loss
		var acceleration = -lava_restoring_force * displacement - segment_data[i]["velocity"] * damping
		
		segment_data[i]["velocity"] += acceleration * safe_delta * lava_physics_speed
		segment_data[i]["velocity"] = clamp(segment_data[i]["velocity"], -3.0, 3.0)
		segment_data[i]["height"] += segment_data[i]["velocity"] * safe_delta * lava_physics_speed
	
	# Wave propagation
	for _update in range(wave_spread_updates):
		for i in range(1, segment_count - 1):
			var left_diff = segment_data[i]["height"] - segment_data[i - 1]["height"]
			var right_diff = segment_data[i]["height"] - segment_data[i + 1]["height"]
			
			segment_data[i - 1]["velocity"] += left_diff * wave_strength * safe_delta * lava_physics_speed
			segment_data[i + 1]["velocity"] += right_diff * wave_strength * safe_delta * lava_physics_speed
	
	# Lock edges
	segment_data[0]["height"] = surface_pos_y
	segment_data[0]["velocity"] = 0.0
	segment_data[segment_count - 1]["height"] = surface_pos_y
	segment_data[segment_count - 1]["velocity"] = 0.0

func _update_visuals() -> void:
	var points: Array[Vector2] = []
	var segment_width = lava_size.x / (segment_count - 1)
	
	for i in range(segment_count):
		var base_height = segment_data[i]["height"]
		
		# Add ambient wave offset
		var ambient_offset = 0.0
		if ambient_wave_enabled:
			var wave_phase = _ambient_wave_time * ambient_wave_speed + (float(i) / segment_count) * TAU / ambient_wave_length
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

func _update_particles(delta: float) -> void:
	_particle_timer += delta
	
	# Spawn new particles
	if _particle_timer >= particle_spawn_rate:
		_particle_timer = 0.0
		_spawn_ember()
	
	# Update existing particles
	var to_remove: Array[Node2D] = []
	for ember in ember_particles:
		if not is_instance_valid(ember):
			to_remove.append(ember)
			continue
		
		# Rise and fade
		ember.position.y -= particle_rise_speed * delta
		ember.position.x += sin(Time.get_ticks_msec() * 0.005 + ember.get_meta("phase", 0.0)) * 10.0 * delta
		
		var age = ember.get_meta("age", 0.0) + delta
		ember.set_meta("age", age)
		
		if age >= particle_lifetime:
			to_remove.append(ember)
		else:
			# Fade out
			var alpha = 1.0 - (age / particle_lifetime)
			var ember_visual = ember.get_node_or_null("Visual") as Polygon2D
			if ember_visual:
				ember_visual.modulate.a = alpha
	
	for ember in to_remove:
		ember_particles.erase(ember)
		if is_instance_valid(ember):
			ember.queue_free()

func _spawn_ember() -> void:
	if ember_particles.size() >= particle_count:
		return
	
	var ember = Node2D.new()
	ember.name = "Ember"
	
	# Random position along lava surface
	var spawn_x = randf() * lava_size.x
	var spawn_y = surface_pos_y + randf_range(-2.0, 2.0)
	ember.position = Vector2(spawn_x, spawn_y)
	
	# Random phase for horizontal wobble
	ember.set_meta("phase", randf() * TAU)
	ember.set_meta("age", 0.0)
	
	# Create visual - small glowing polygon
	var visual = Polygon2D.new()
	visual.name = "Visual"
	
	# Small diamond/spark shape
	var size = randf_range(1.5, 3.0)
	visual.polygon = PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.6, 0),
		Vector2(0, size * 0.5),
		Vector2(-size * 0.6, 0)
	])
	
	# Random orange/yellow color
	var hue_shift = randf_range(-0.05, 0.1)
	visual.color = Color(1.0, 0.5 + hue_shift, 0.1 - hue_shift * 0.5, 1.0)
	
	ember.add_child(visual)
	add_child(ember)
	ember_particles.append(ember)

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
	if body.has_method("die"):
		body.die()
	elif body is CharacterBody2D:
		# Fallback: try to find hurt signal or just free
		var hurt_area = body.get_node_or_null("Direction/HurtArea2D")
		if hurt_area and hurt_area.has_signal("hurt"):
			hurt_area.emit_signal("hurt", Vector2.ZERO, 9999)
		elif body.has_method("take_damage"):
			body.take_damage(9999)

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

## ============================================================================
## BUBBLE SYSTEM
## Bubbles rise from within the lava and pop at the surface
## ============================================================================

func _update_bubbles(delta: float) -> void:
	_bubble_timer += delta
	
	# Spawn new bubbles
	if _bubble_timer >= bubble_spawn_interval and bubble_particles.size() < bubble_count:
		_bubble_timer = 0.0
		_spawn_bubble()
	
	# Update existing bubbles
	var to_remove: Array[Node2D] = []
	for bubble in bubble_particles:
		if not is_instance_valid(bubble):
			to_remove.append(bubble)
			continue
		
		# Rise toward surface
		bubble.position.y -= bubble_rise_speed * delta
		
		# Slight horizontal wobble
		var wobble_phase = bubble.get_meta("wobble_phase", 0.0)
		bubble.position.x += sin(wobble_phase + Time.get_ticks_msec() * 0.005) * 8.0 * delta
		
		# Grow slightly as it rises (pressure release)
		var start_size = bubble.get_meta("start_size", bubble_min_size)
		var growth = bubble.get_meta("growth", 0.0) + delta * 0.3
		bubble.set_meta("growth", growth)
		
		var visual = bubble.get_node_or_null("Visual") as Polygon2D
		if visual:
			var current_size = start_size + growth
			visual.scale = Vector2(current_size / start_size, current_size / start_size)
		
		# Check if reached surface - pop!
		if bubble.position.y <= surface_pos_y:
			_pop_bubble(bubble)
			to_remove.append(bubble)
	
	# Cleanup
	for bubble in to_remove:
		bubble_particles.erase(bubble)
		if is_instance_valid(bubble):
			bubble.queue_free()

func _spawn_bubble() -> void:
	var bubble = Node2D.new()
	bubble.name = "Bubble"
	
	# Random position within lava body (below surface)
	var spawn_depth = randf_range(lava_size.y * 0.3, lava_size.y * 0.8)
	bubble.position = Vector2(
		randf_range(lava_size.x * 0.1, lava_size.x * 0.9),
		spawn_depth
	)
	
	var size = randf_range(bubble_min_size, bubble_max_size)
	bubble.set_meta("start_size", size)
	bubble.set_meta("growth", 0.0)
	bubble.set_meta("wobble_phase", randf() * TAU)
	
	# Create bubble visual - circle approximation
	var visual = Polygon2D.new()
	visual.name = "Visual"
	
	var points: PackedVector2Array = []
	for i in range(8):
		var angle = (float(i) / 8.0) * TAU
		points.append(Vector2(cos(angle) * size, sin(angle) * size))
	visual.polygon = points
	
	# Lighter orange/yellow - hot gas inside
	visual.color = Color(1.0, 0.7, 0.2, 0.7)
	
	# Add highlight for 3D effect
	var highlight = Polygon2D.new()
	highlight.name = "Highlight"
	var hl_size = size * 0.4
	var hl_points: PackedVector2Array = []
	for i in range(6):
		var angle = (float(i) / 6.0) * TAU
		hl_points.append(Vector2(cos(angle) * hl_size - size * 0.3, sin(angle) * hl_size - size * 0.3))
	highlight.polygon = hl_points
	highlight.color = Color(1.0, 0.9, 0.5, 0.5)
	
	visual.add_child(highlight)
	bubble.add_child(visual)
	add_child(bubble)
	bubble_particles.append(bubble)

func _pop_bubble(bubble: Node2D) -> void:
	## Create a small surface disturbance when bubble pops
	var segment_width = lava_size.x / (segment_count - 1)
	var index = int(clamp(bubble.position.x / segment_width, 1, segment_count - 2))
	
	# Small upward splash
	var pop_strength = bubble.get_meta("start_size", bubble_min_size) * -0.3
	segment_data[index]["velocity"] += pop_strength

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
	
	# Update all segment heights to follow
	for i in range(segment_count):
		segment_data[i]["height"] = surface_pos_y
	
	# Update collision shape position
	if lava_area:
		var collision = lava_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision:
			collision.position.y = surface_pos_y + (lava_size.y - surface_pos_y) / 2.0
	
	# Update light position
	if lava_light:
		lava_light.position.y = surface_pos_y
	
	if progress >= 1.0:
		_drain_active = false
		
		if _is_draining:
			lava_drained.emit()
		else:
			# Re-enable damage when filled
			_set_damage_enabled(true)
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
