extends Area2D
class_name Whirlpool

## 2D water hazard creating V-shaped depression and vortex current
## Creates 90px deep V-depression with center vertical axis
## Pulls entities toward center line with oscillating horizontal forces

@export_group("Whirlpool Settings")
@export var strength: float = 2000.0      ## Inward pull force strength
@export var damage_dps: float = 10.0      ## Damage per second at center
@export var lifetime: float = 8.0         ## Duration before despawn (0 = infinite)
@export var auto_despawn: bool = true     ## Auto-remove when lifetime expires

@export_group("Water Depression")
@export var depression_depth: float = 67.0  ## Water depression depth in pixels (V-depth at center)
@export var depression_width: float = 120.0  ## Horizontal radius of depression influence

@export_group("Advanced Tuning")
@export var boat_influence: float = 1.2   ## Boat pull multiplier

@export_group("Visuals")
@export var enable_visuals: bool = true  ## Show foam and spiral effect

@export_group("Glow Light (Optional)")
@export var emit_light: bool = false  ## Eerie underwater glow
@export var light_color: Color = Color(0.2, 0.6, 0.9, 0.8)  ## Deep blue vortex glow
@export var light_energy: float = 0.5  ## Glow brightness
@export var light_texture_scale: float = 2.5  ## Glow radius
@export var light_pulse_enabled: bool = true  ## Pulsing synchronized with oscillation
@export var light_pulse_amount: float = 0.3  ## Pulse intensity

const OSCILLATION_STRENGTH: float = 1500.0        ## Horizontal bobbing force
const OSCILLATION_FREQUENCY: float = 3.0           ## Oscillation speed (Hz)
const DOWNWARD_SUCTION: float = 2500.0             ## Vertical pull into V
const CENTER_LINE_WIDTH: float = 40.0              ## Width of maximum suction zone
const DRAG_COEFFICIENT: float = 0.4                ## Movement dampening coefficient (lower = more drag)
const DAMAGE_COOLDOWN: float = 0.5                 ## Damage tick interval

const MAX_HORIZONTAL_VELOCITY: float = 400.0       ## Hard cap on horizontal pull speed
const MAX_VERTICAL_VELOCITY: float = 500.0         ## Hard cap on downward suction speed

const WATER_CHECK_INTERVAL: float = 0.5            ## How often to verify we're still in water (seconds)
const SEGMENT_BUFFER_MARGIN: int = 2               ## Extra segments to affect beyond calculated radius

var center_x: float
var center_y: float
var damage_cooldown_timer: float = 0.0
var lifetime_timer: float = 0.0
var oscillation_phase: float = 0.0
var water_check_timer: float = 0.0

var boats_in_range: Array = []
var player_in_range: Node2D = null
var water_node: water = null
var depression_applied: bool = false

## GPU Particle reference
var water_particles: GPUParticles2D = null
var vortex_visual: Line2D = null
var inner_vortex: Line2D = null
var _vortex_light: PointLight2D = null
var _base_light_energy: float = 0.5

func _ready() -> void:
	center_x = global_position.x
	center_y = global_position.y
	lifetime_timer = lifetime
	
	# Track node removals to clean stale body references (player death scenario)
	get_tree().node_removed.connect(_on_any_node_removed)
	
	# Get collision shape size from scene
	var collision_shape = $PullRadius as CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect = collision_shape.shape as RectangleShape2D
		# Use depression_width for horizontal influence, keep vertical from shape
		rect.size = Vector2(depression_width, rect.size.y)
	else:
		push_error("Whirlpool: PullRadius must use RectangleShape2D!")
	
	_find_water_node()
	
	if water_node:
		call_deferred("_apply_water_depression")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Setup GPU particles for V-shaped midsection view
	if enable_visuals:
		water_particles = get_node_or_null("WaterParticles") as GPUParticles2D
		if water_particles:
			_configure_vortex_particles()
			water_particles.emitting = true
		
		# Get visual lines for rotation animation
		vortex_visual = get_node_or_null("VortexVisual") as Line2D
		inner_vortex = get_node_or_null("InnerVortex") as Line2D
	
	# Optional vortex glow
	if emit_light:
		_create_vortex_light()

func _physics_process(delta: float) -> void:
	oscillation_phase += delta * OSCILLATION_FREQUENCY * TAU
	
	# Animate vortex visual lines rotation
	if vortex_visual:
		vortex_visual.rotation += delta * 1.5  # Slower outer rotation
	if inner_vortex:
		inner_vortex.rotation -= delta * 2.5  # Faster counter-rotation
	
	# Vortex light pulsing synchronized with oscillation
	if emit_light and _vortex_light and light_pulse_enabled:
		var pulse = sin(oscillation_phase * 0.5) * light_pulse_amount
		_vortex_light.energy = _base_light_energy * (1.0 + pulse)
	
	if damage_cooldown_timer > 0:
		damage_cooldown_timer -= delta
	
	if auto_despawn and lifetime > 0:
		lifetime_timer -= delta
		if lifetime_timer <= 0:
			_on_lifetime_expired()
			return
	
	# Periodic check: Are we still in water?
	water_check_timer -= delta
	if water_check_timer <= 0:
		water_check_timer = WATER_CHECK_INTERVAL
		# Retry finding water node if not found initially (timing issue workaround)
		if not water_node:
			_find_water_node()
		elif not _is_in_water():
			# Water level dropped, despawn gracefully
			_on_water_disappeared()
			return
	
	if water_node and not depression_applied:
		_apply_water_depression()
	
	_update_boat_pulls(delta)
	_update_player_interaction(delta)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("platform"):
		if not boats_in_range.has(body):
			boats_in_range.append(body)
	elif body.is_in_group("player"):
		player_in_range = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("platform"):
		boats_in_range.erase(body)
	elif body.is_in_group("player"):
		if player_in_range == body:
			player_in_range = null


func _exit_tree() -> void:
	# Disconnect node removal tracking
	if get_tree() and get_tree().node_removed.is_connected(_on_any_node_removed):
		get_tree().node_removed.disconnect(_on_any_node_removed)


func _on_any_node_removed(node: Node) -> void:
	# Clean stale body references when nodes are freed (e.g., player death)
	if boats_in_range.has(node):
		boats_in_range.erase(node)
	if player_in_range == node:
		player_in_range = null


func _update_boat_pulls(delta: float) -> void:
	for boat in boats_in_range:
		if not is_instance_valid(boat):
			boats_in_range.erase(boat)
			continue
		
		_apply_pull_to_boat(boat, delta)

func _apply_pull_to_boat(boat, delta: float) -> void:
	var horizontal_distance = abs(boat.global_position.x - center_x)
	var vertical_distance = abs(boat.global_position.y - center_y)
	
	if horizontal_distance > depression_width / 2.0:
		return
	# Keep vertical check reasonable (slightly larger than depression width for lenient zone)
	if vertical_distance > depression_width:
		return
	
	var direction_to_center = sign(center_x - boat.global_position.x)
	var linear_falloff = clamp(1.0 - (horizontal_distance / (depression_width / 2.0)), 0.0, 1.0)
	
	var pull_toward_line = direction_to_center * strength * boat_influence * linear_falloff
	var oscillation = sin(oscillation_phase) * OSCILLATION_STRENGTH * boat_influence * linear_falloff * 0.5
	
	if "is_gliding" in boat:
		boat.is_gliding = false
	
	if "external_force_x" in boat:
		boat.external_force_x += (pull_toward_line + oscillation) * delta
	else:
		boat.velocity_x += (pull_toward_line + oscillation) * delta
	
	if horizontal_distance < CENTER_LINE_WIDTH:
		var chaos_strength = linear_falloff * 150.0
		var vertical_chaos = sin(Time.get_ticks_msec() * 0.01) * chaos_strength * delta
		if "external_force_y" in boat:
			boat.external_force_y += vertical_chaos
		else:
			boat.velocity_y += vertical_chaos

func _update_player_interaction(delta: float) -> void:
	if not player_in_range:
		return
	
	var player = player_in_range
	if not is_instance_valid(player):
		player_in_range = null
		return
	
	var horizontal_distance = abs(player.global_position.x - center_x)
	var vertical_distance = abs(player.global_position.y - center_y)
	
	if horizontal_distance > depression_width / 2.0:
		return
	if vertical_distance > depression_width:
		return
	
	var is_underwater = player.is_head_underwater(5.0)
	
	if not is_underwater:
		_apply_surface_current(player, horizontal_distance, delta)
	else:
		_apply_underwater_vortex(player, horizontal_distance, delta)
	
	if horizontal_distance < depression_width / 4.0:
		_apply_damage_to_player(player)

func _apply_surface_current(player, horizontal_distance: float, delta: float) -> void:
	var direction_to_center = sign(center_x - player.global_position.x)
	var linear_falloff = clamp(1.0 - (horizontal_distance / (depression_width / 2.0)), 0.0, 1.0)
	
	# Apply drag first to prevent accumulation
	player.velocity.x *= DRAG_COEFFICIENT
	
	var pull_toward_line = direction_to_center * strength * linear_falloff
	var oscillation = sin(oscillation_phase) * OSCILLATION_STRENGTH * linear_falloff
	
	player.velocity.x += (pull_toward_line + oscillation) * delta
	
	# Hard cap to prevent yeeting
	player.velocity.x = clamp(player.velocity.x, -MAX_HORIZONTAL_VELOCITY, MAX_HORIZONTAL_VELOCITY)

func _apply_underwater_vortex(player, horizontal_distance: float, delta: float) -> void:
	var direction_to_center = sign(center_x - player.global_position.x)
	var linear_falloff = clamp(1.0 - (horizontal_distance / (depression_width / 2.0)), 0.0, 1.0)
	
	# Apply drag FIRST to prevent exponential growth
	player.velocity.x *= DRAG_COEFFICIENT
	player.velocity.y *= DRAG_COEFFICIENT
	
	# Reduced underwater multiplier (1.5 -> 1.2) to prevent violence
	var pull_toward_line = direction_to_center * strength * linear_falloff * 1.2
	var oscillation = sin(oscillation_phase) * OSCILLATION_STRENGTH * linear_falloff * 1.2
	
	player.velocity.x += (pull_toward_line + oscillation) * delta
	
	if horizontal_distance < CENTER_LINE_WIDTH:
		var suction_strength = 1.0 - (horizontal_distance / CENTER_LINE_WIDTH)
		var downward_force = DOWNWARD_SUCTION * suction_strength
		player.velocity.y += downward_force * delta
		
		if suction_strength > 0.3:
			player.velocity.y = max(player.velocity.y, 250.0)
	
	# Hard caps to prevent player yeeting
	player.velocity.x = clamp(player.velocity.x, -MAX_HORIZONTAL_VELOCITY, MAX_HORIZONTAL_VELOCITY)
	player.velocity.y = clamp(player.velocity.y, -MAX_VERTICAL_VELOCITY, MAX_VERTICAL_VELOCITY)

func _apply_damage_to_player(player) -> void:
	if damage_cooldown_timer > 0:
		return
	
	var hurt_area = player.get_node_or_null("Direction/HurtArea2D")
	if hurt_area and hurt_area.has_signal("hurt"):
		hurt_area.emit_signal("hurt", Vector2.ZERO, damage_dps * DAMAGE_COOLDOWN)
	
	damage_cooldown_timer = DAMAGE_COOLDOWN


func _on_lifetime_expired() -> void:
	_restore_water_rest_heights()
	queue_free()

func _restore_water_rest_heights() -> void:
	if not water_node:
		return
	
	var segment_info = _get_affected_segment_range()
	if segment_info["center_index"] < 0:
		return
	
	var center_index = segment_info["center_index"]
	var range_segments = segment_info["range"]
	var segment_count = segment_info["segment_count"]
	
	for offset in range(-range_segments, range_segments + 1):
		var segment_idx = center_index + offset
		if segment_idx < 0 or segment_idx >= segment_count:
			continue
		
		water_node.segment_rest_height[segment_idx] = water_node.surface_pos_y
	
	# Wake up segments when restoring rest heights (for smooth transition back to flat)
	if "_settled_segments" in water_node and water_node._settled_segments.size() > 0:
		for offset in range(-range_segments, range_segments + 1):
			var segment_idx = center_index + offset
			if segment_idx < 0 or segment_idx >= segment_count:
				continue
			water_node._settled_segments[segment_idx] = 0


func _get_affected_segment_range() -> Dictionary:
	if not water_node:
		return {"center_index": -1, "range": 0}
	
	var segment_count = water_node.segment_count
	var segment_width = water_node.water_size.x / (segment_count - 1)
	var water_local_center_x = water_node.to_local(Vector2(center_x, center_y)).x
	var center_segment_index = int(clamp(water_local_center_x / segment_width, 0, segment_count - 1))
	var influence_radius_segments = int((depression_width / 2.0) / segment_width) + SEGMENT_BUFFER_MARGIN
	
	return {
		"center_index": center_segment_index,
		"range": influence_radius_segments,
		"segment_width": segment_width,
		"segment_count": segment_count
	}

func _apply_water_depression() -> void:
	if not water_node or depression_applied:
		return
	
	# CRITICAL: Wait for water level transition to complete before applying depression
	# Otherwise the water's _update_water_raise() will overwrite our segment modifications
	if water_node.is_level_transitioning():
		# Don't apply yet - will retry in _physics_process
		return
	
	var segment_info = _get_affected_segment_range()
	if segment_info["center_index"] < 0:
		return
	
	var center_index = segment_info["center_index"]
	var range_segments = segment_info["range"]
	var segment_width = segment_info["segment_width"]
	var segment_count = segment_info["segment_count"]
	
	var segments_modified = 0
	for offset in range(-range_segments, range_segments + 1):
		var segment_idx = center_index + offset
		if segment_idx < 0 or segment_idx >= segment_count:
			continue
		
		var distance_from_center = abs(offset * segment_width)
		var falloff = 1.0 - clamp(distance_from_center / (depression_width / 2.0), 0.0, 1.0)
		falloff = falloff * falloff
		
		var old_rest = water_node.segment_rest_height[segment_idx]
		var target_rest_height = water_node.surface_pos_y + (depression_depth * falloff)
		water_node.segment_rest_height[segment_idx] = target_rest_height
		segments_modified += 1
	
	# CRITICAL: Wake up affected segments so they respond to new rest heights
	# Without this, settled segments will ignore the depression
	if "_settled_segments" in water_node and water_node._settled_segments.size() > 0:
		for offset in range(-range_segments, range_segments + 1):
			var segment_idx = center_index + offset
			if segment_idx < 0 or segment_idx >= segment_count:
				continue
			water_node._settled_segments[segment_idx] = 0
			
			# Also wake immediate neighbors to ensure wave propagation
			if segment_idx > 0:
				water_node._settled_segments[segment_idx - 1] = 0
			if segment_idx < segment_count - 1:
				water_node._settled_segments[segment_idx + 1] = 0
	
	depression_applied = true
	water_node.recently_splashed = true
	water_node.set_process(true)

func _configure_vortex_particles() -> void:
	## Configure particles for vertical V-shaped vortex (midsection view)
	if not water_particles or not water_particles.process_material:
		return
	
	var mat = water_particles.process_material as ParticleProcessMaterial
	if not mat:
		return
	
	# CRITICAL: Vertical line emission for midsection V-shape, not horizontal circle
	# Particles spawn along center vertical line and spiral outward
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(8, depression_depth * 0.7, 0)  # Narrow X, tall Y for vertical line
	
	# Horizontal spread (left/right from center line)
	mat.direction = Vector3(1, 0, 0)  # Primarily horizontal spread
	mat.spread = 180.0  # Full horizontal spread
	
	# Add upward drift for foam floating up from vortex
	mat.gravity = Vector3(0, -30, 0)  # Slight upward float
	
	# Circular motion around center
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	
	# Turbulent motion
	mat.initial_velocity_min = 25.0
	mat.initial_velocity_max = 60.0
	mat.linear_accel_min = -20.0
	mat.linear_accel_max = 20.0
	
	# Visual - white foam swirls
	mat.color = Color(0.95, 0.98, 1.0, 0.9)
	
	# Scale and fade
	mat.scale_min = 1.5
	mat.scale_max = 3.5
	mat.damping_min = 1.5
	mat.damping_max = 3.0

func _find_water_node() -> void:
	var water_nodes = get_tree().get_nodes_in_group("water")
	
	for node in water_nodes:
		var local_pos = node.to_local(Vector2(center_x, center_y))
		if local_pos.x >= 0 and local_pos.x <= node.water_size.x:
			if local_pos.y >= node.surface_pos_y and local_pos.y <= node.water_size.y:
				water_node = node
				return

func _is_in_water() -> bool:
	## Check if whirlpool center is currently submerged in water
	## Returns false if water level has dropped below us
	if not water_node:
		return false
	
	# Get current water surface at our X position
	var water_surface_y = water_node.get_water_surface_global_y()
	
	# We need to be at least partially underwater
	# Check if our center is below the water surface
	if center_y < water_surface_y:
		return false  # We're above water
	
	# Also verify we're still within water's horizontal bounds
	var local_pos = water_node.to_local(Vector2(center_x, center_y))
	if local_pos.x < 0 or local_pos.x > water_node.water_size.x:
		return false  # Outside water bounds
	
	return true

func _on_water_disappeared() -> void:
	## Called when water level drops and whirlpool is no longer submerged
	## Gracefully despawn to prevent air whirlpools
	_restore_water_rest_heights()
	queue_free()


func _create_vortex_light() -> void:
	## Creates an eerie underwater glow at the vortex center
	_vortex_light = PointLight2D.new()
	_vortex_light.enabled = true
	_vortex_light.color = light_color
	_vortex_light.energy = light_energy
	_vortex_light.texture_scale = light_texture_scale
	_vortex_light.blend_mode = Light2D.BLEND_MODE_ADD
	_vortex_light.shadow_enabled = false
	_vortex_light.range_z_min = -100
	_vortex_light.range_z_max = 100
	_vortex_light.position = Vector2.ZERO  # Center of vortex
	_vortex_light.z_index = ZLayers.LIGHT_EFFECT
	
	# Radial gradient texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.0, 0.5)
	_vortex_light.texture = tex
	
	_base_light_energy = light_energy
	add_child(_vortex_light)
