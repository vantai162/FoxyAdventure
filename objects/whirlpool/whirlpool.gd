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

@export_group("Advanced Tuning")
@export var boat_influence: float = 1.2   ## Boat pull multiplier

const OSCILLATION_STRENGTH: float = 1500.0        ## Horizontal bobbing force
const OSCILLATION_FREQUENCY: float = 3.0           ## Oscillation speed (Hz)
const DOWNWARD_SUCTION: float = 2500.0             ## Vertical pull into V
const CENTER_LINE_WIDTH: float = 40.0              ## Width of maximum suction zone
const DRAG_COEFFICIENT: float = 0.4                ## Movement dampening coefficient (lower = more drag)
const DAMAGE_COOLDOWN: float = 0.5                 ## Damage tick interval

const MAX_HORIZONTAL_VELOCITY: float = 400.0       ## Hard cap on horizontal pull speed
const MAX_VERTICAL_VELOCITY: float = 500.0         ## Hard cap on downward suction speed

const WATER_CHECK_INTERVAL: float = 0.5            ## How often to verify we're still in water (seconds)

const DEPRESSION_DEPTH: float = 90.0               ## Water depression depth in pixels
const SEGMENT_BUFFER_MARGIN: int = 2               ## Extra segments to affect beyond calculated radius

var center_x: float
var center_y: float
var whirlpool_width: float = 160.0
var whirlpool_depth: float = 200.0
var damage_cooldown_timer: float = 0.0
var lifetime_timer: float = 0.0
var oscillation_phase: float = 0.0
var water_check_timer: float = 0.0

var boats_in_range: Array = []
var player_in_range: Node2D = null
var water_node: water = null
var depression_applied: bool = false

func _ready() -> void:
	center_x = global_position.x
	center_y = global_position.y
	lifetime_timer = lifetime
	
	var collision_shape = $PullRadius as CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect = collision_shape.shape as RectangleShape2D
		whirlpool_width = rect.size.x
		whirlpool_depth = rect.size.y
	else:
		push_error("Whirlpool: PullRadius must use RectangleShape2D!")
	
	_find_water_node()
	
	if water_node:
		call_deferred("_apply_water_depression")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_setup_visuals()

func _physics_process(delta: float) -> void:
	oscillation_phase += delta * OSCILLATION_FREQUENCY * TAU
	
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
		if not _is_in_water():
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

func _update_boat_pulls(delta: float) -> void:
	for boat in boats_in_range:
		if not is_instance_valid(boat):
			boats_in_range.erase(boat)
			continue
		
		_apply_pull_to_boat(boat, delta)

func _apply_pull_to_boat(boat, delta: float) -> void:
	var horizontal_distance = abs(boat.global_position.x - center_x)
	var vertical_distance = abs(boat.global_position.y - center_y)
	
	if horizontal_distance > whirlpool_width / 2.0:
		return
	if vertical_distance > whirlpool_depth / 2.0:
		return
	
	var direction_to_center = sign(center_x - boat.global_position.x)
	var linear_falloff = clamp(1.0 - (horizontal_distance / (whirlpool_width / 2.0)), 0.0, 1.0)
	
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
	
	if horizontal_distance > whirlpool_width / 2.0:
		return
	if vertical_distance > whirlpool_depth / 2.0:
		return
	
	var is_underwater = player.is_head_underwater(5.0)
	
	if not is_underwater:
		_apply_surface_current(player, horizontal_distance, delta)
	else:
		_apply_underwater_vortex(player, horizontal_distance, delta)
	
	if horizontal_distance < whirlpool_width / 4.0:
		_apply_damage_to_player(player)

func _apply_surface_current(player, horizontal_distance: float, delta: float) -> void:
	var direction_to_center = sign(center_x - player.global_position.x)
	var linear_falloff = clamp(1.0 - (horizontal_distance / (whirlpool_width / 2.0)), 0.0, 1.0)
	
	# Apply drag first to prevent accumulation
	player.velocity.x *= DRAG_COEFFICIENT
	
	var pull_toward_line = direction_to_center * strength * linear_falloff
	var oscillation = sin(oscillation_phase) * OSCILLATION_STRENGTH * linear_falloff
	
	player.velocity.x += (pull_toward_line + oscillation) * delta
	
	# Hard cap to prevent yeeting
	player.velocity.x = clamp(player.velocity.x, -MAX_HORIZONTAL_VELOCITY, MAX_HORIZONTAL_VELOCITY)

func _apply_underwater_vortex(player, horizontal_distance: float, delta: float) -> void:
	var direction_to_center = sign(center_x - player.global_position.x)
	var linear_falloff = clamp(1.0 - (horizontal_distance / (whirlpool_width / 2.0)), 0.0, 1.0)
	
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
	_play_despawn_effect()
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

func _setup_visuals() -> void:
	pass

func _play_despawn_effect() -> void:
	pass

func _get_affected_segment_range() -> Dictionary:
	if not water_node:
		return {"center_index": -1, "range": 0}
	
	var segment_count = water_node.segment_count
	var segment_width = water_node.water_size.x / (segment_count - 1)
	var water_local_center_x = water_node.to_local(Vector2(center_x, center_y)).x
	var center_segment_index = int(clamp(water_local_center_x / segment_width, 0, segment_count - 1))
	var influence_radius_segments = int((whirlpool_width / 2.0) / segment_width) + SEGMENT_BUFFER_MARGIN
	
	return {
		"center_index": center_segment_index,
		"range": influence_radius_segments,
		"segment_width": segment_width,
		"segment_count": segment_count
	}

func _apply_water_depression() -> void:
	if not water_node or depression_applied:
		return
	
	var segment_info = _get_affected_segment_range()
	if segment_info["center_index"] < 0:
		return
	
	var center_index = segment_info["center_index"]
	var range_segments = segment_info["range"]
	var segment_width = segment_info["segment_width"]
	var segment_count = segment_info["segment_count"]
	
	for offset in range(-range_segments, range_segments + 1):
		var segment_idx = center_index + offset
		if segment_idx < 0 or segment_idx >= segment_count:
			continue
		
		var distance_from_center = abs(offset * segment_width)
		var falloff = 1.0 - clamp(distance_from_center / (whirlpool_width / 2.0), 0.0, 1.0)
		falloff = falloff * falloff
		
		var target_rest_height = water_node.surface_pos_y + (DEPRESSION_DEPTH * falloff)
		water_node.segment_rest_height[segment_idx] = target_rest_height
	
	depression_applied = true
	water_node.recently_splashed = true
	water_node.set_process(true)

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
