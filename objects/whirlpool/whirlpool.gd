extends Area2D
class_name Whirlpool

## Deadly water hazard that pulls boats and traps players underwater
## Uses Area2D body_entered/exited signals (event-driven, follows codebase pattern like water.gd)

@export_group("Whirlpool Settings")
@export var strength: float = 200.0      ## Master strength (affects pull, trap, and visuals)
@export var radius: float = 180.0        ## Outer pull radius
@export var core_radius: float = 80.0    ## Inner danger/visual radius (wider = more natural depression)
@export var damage_dps: float = 10.0     ## Damage per second at center
@export var lifetime: float = 8.0        ## Duration (0 = infinite)
@export var auto_despawn: bool = true    ## Automatically remove when lifetime expires

@export_group("Advanced Tuning")
@export var boat_influence: float = 1.2  ## Multiplier for boat pull

# Internal constants (formerly exports)
const FALLOFF_POWER: float = 2.0
const UNDERWATER_TRAP_MULTIPLIER: float = 2.0
const DISTURBANCE_PULSE_INTERVAL: float = 0.1  ## Slow update rate for gentle, sustained depression
const DISTURBANCE_PULSE_FORCE: float = 8.0   ## Light edge turbulence (was causing tsunami at 15)
const CENTER_STRONG_TRAP_THRESHOLD: float = 0.7
const DRAG_COEFFICIENT: float = 0.95
const DAMAGE_COOLDOWN: float = 0.5

# Depression constants (physical depression via rest height modification)
const DEPRESSION_DEPTH: float = 90.0         ## Deep visible depression - wide natural whirlpool!
const DEPRESSION_LERP_SPEED: float = 0.15    ## Faster transition (critical damping prevents violence)
const VELOCITY_DAMPING: float = 0.7          ## Damping for stability

var center_point: Vector2
var damage_cooldown_timer: float = 0.0
var lifetime_timer: float = 0.0
var disturbance_timer: float = 0.0  ## Timer for pulsed water effects

# Track entities currently in range (event-driven pattern from water.gd)
var boats_in_range: Array = []
var player_in_range: Node2D = null
var water_node: water = null  ## Reference to water node for disturbance effects
var depression_applied: bool = false  ## Track if we've set rest heights

func _ready() -> void:
	add_to_group("whirlpool")
	add_to_group("hazard")
	center_point = global_position
	lifetime_timer = lifetime
	
	# Find water node in scene (should be in "water" group)
	_find_water_node()
	
	# Defer depression application to next frame (ensure water is fully initialized)
	if water_node:
		call_deferred("_setup_depression_targets")
	
	# Setup Area2D for detection (codebase pattern)
	collision_layer = 32  # Environmental hazard layer
	collision_mask = 2    # Detect player layer
	monitoring = true
	monitorable = false
	
	# Setup collision shape for pull radius
	var collision_shape = $PullRadius as CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius
	
	# Connect Area2D signals (codebase pattern like water.gd)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_setup_visuals()

func _physics_process(delta: float) -> void:
	# Update timers
	if damage_cooldown_timer > 0:
		damage_cooldown_timer -= delta
	
	if auto_despawn and lifetime > 0:
		lifetime_timer -= delta
		if lifetime_timer <= 0:
			_on_lifetime_expired()
			return
	
	# Gradually apply depression (smooth transition)
	if water_node and not depression_applied:
		_update_water_depression(delta)
	
	# Update interactions (only for tracked entities)
	_update_boat_pulls(delta)
	_update_player_interaction(delta)

## === EVENT HANDLERS (Codebase Pattern) ===

func _on_body_entered(body: Node2D) -> void:
	## Handle entity entering whirlpool range
	if body.is_in_group("platform"):
		# Track boats for pull physics
		if not boats_in_range.has(body):
			boats_in_range.append(body)
	elif body.is_in_group("player"):
		# Track player for trap mechanics
		player_in_range = body

func _on_body_exited(body: Node2D) -> void:
	## Handle entity leaving whirlpool range
	if body.is_in_group("platform"):
		boats_in_range.erase(body)
	elif body.is_in_group("player"):
		if player_in_range == body:
			player_in_range = null

## === BOAT PULL MECHANICS ===

func _update_boat_pulls(delta: float) -> void:
	## Apply pull forces to all boats in range
	for boat in boats_in_range:
		if not is_instance_valid(boat):
			boats_in_range.erase(boat)
			continue
		
		_apply_pull_to_boat(boat, delta)

func _apply_pull_to_boat(boat, delta: float) -> void:
	## Calculate and apply pull force to a single boat
	## FloatingBoatPlatform uses velocity_x/velocity_y (floats), not Vector2 velocity
	var distance = boat.global_position.distance_to(center_point)
	
	if distance < 1.0:
		return  # Already at center
	
	# Inverse square falloff
	var falloff = 1.0 - (distance / radius)
	falloff = clamp(falloff * falloff, 0.0, 1.0)
	
	# Direction toward center
	var direction = (center_point - boat.global_position).normalized()
	
	# Apply pull force - FloatingBoatPlatform uses velocity_x and velocity_y
	var pull_force = strength * boat_influence * falloff
	
	# Override boat's self-propulsion if pull is strong enough
	if falloff > 0.1:
		# Disable gliding to prevent boat from fighting the pull
		if "is_gliding" in boat:
			boat.is_gliding = false
			
		# Apply direct velocity modification
		boat.velocity_x += direction.x * pull_force * delta
		
		# Add vertical chaos near center to destabilize boat
		if falloff > 0.3:  # When close enough to feel danger
			var chaos_strength = falloff * 100.0  # Scales with proximity
			boat.velocity_y += sin(Time.get_ticks_msec() * 0.01) * chaos_strength * delta

## === PLAYER INTERACTION ===

func _update_player_interaction(delta: float) -> void:
	## Handle player pull and underwater trap
	if not player_in_range:
		return
	
	var player = player_in_range
	if not is_instance_valid(player):
		player_in_range = null
		return
	
	var distance = player.global_position.distance_to(center_point)
	
	if distance > radius:
		return  # Out of range (shouldn't happen, but safety check)
	
	var direction = (center_point - player.global_position).normalized()
	var falloff = 1.0 - (distance / radius)
	falloff = falloff * falloff
	
	# Check if player is underwater (use player's centralized method)
	var is_underwater = player.is_head_underwater(5.0)  # 5.0 threshold for surface splashing
	
	if not is_underwater:
		# Surface pull (gentle when on boat or in air)
		_apply_surface_pull(player, direction, falloff, delta)
	else:
		# UNDERWATER TRAP - the key mechanic
		_apply_underwater_trap(player, direction, falloff, delta)
	
	# Center damage zone
	if distance < core_radius:
		_apply_damage_to_player(player)

func _apply_surface_pull(player, direction: Vector2, falloff: float, delta: float) -> void:
	## Gentle pull when player is on surface or in air near whirlpool
	var pull_force = strength * falloff * 0.5  # Half strength on surface
	player.velocity += direction * pull_force * delta

func _apply_underwater_trap(player, direction: Vector2, falloff: float, delta: float) -> void:
	## The deadly underwater current that traps players
	
	# Strong horizontal pull toward center
	var horizontal_pull = strength * falloff * 1.5
	player.velocity.x += direction.x * horizontal_pull * delta
	
	# DOWNWARD FORCE - fights against swim upward attempts
	var downward_force = (strength * UNDERWATER_TRAP_MULTIPLIER) * falloff
	player.velocity.y += downward_force * delta
	
	# Near center: completely prevent upward movement (the trap snaps shut)
	if falloff > CENTER_STRONG_TRAP_THRESHOLD:
		# Clamp upward velocity to prevent escaping via swimming
		player.velocity.y = max(player.velocity.y, 50.0)  # Allow only downward/neutral
	
	# Apply drag to slow all escape attempts
	player.velocity *= DRAG_COEFFICIENT

func _apply_damage_to_player(player) -> void:
	## Damage tick for center danger zone
	if damage_cooldown_timer > 0:
		return  # Still on cooldown
	
	# Apply damage (player has hurt area system)
	var hurt_area = player.get_node_or_null("Direction/HurtArea2D")
	if hurt_area and hurt_area.has_signal("hurt"):
		# Direction doesn't matter for environmental damage, use zero vector
		hurt_area.emit_signal("hurt", Vector2.ZERO, damage_dps * DAMAGE_COOLDOWN)
	
	damage_cooldown_timer = DAMAGE_COOLDOWN

func _on_lifetime_expired() -> void:
	## Called when whirlpool reaches end of life
	_restore_water_rest_heights()
	_play_despawn_effect()
	queue_free()

func _restore_water_rest_heights() -> void:
	## Reset water rest heights to surface when whirlpool despawns
	if not water_node:
		return
	
	var segment_count = water_node.segment_count
	var segment_width = water_node.water_size.x / (segment_count - 1)
	var water_local_center = water_node.to_local(center_point)
	var center_segment_index = int(clamp(water_local_center.x / segment_width, 0, segment_count - 1))
	var influence_radius_segments = int(core_radius / segment_width) + 2
	
	for offset in range(-influence_radius_segments, influence_radius_segments + 1):
		var segment_idx = center_segment_index + offset
		if segment_idx < 0 or segment_idx >= segment_count:
			continue
		
		# Reset to surface level (water will naturally rise back up)
		water_node.segment_rest_height[segment_idx] = water_node.surface_pos_y

## === VISUAL HOOKS (To be implemented) ===

func _setup_visuals() -> void:
	## Hook for setting up visual effects
	# Will be implemented when real sprite asset is integrated
	# Current: placeholder sprite handles its own visuals
	pass

func _play_despawn_effect() -> void:
	## Hook for despawn animation/particles
	# Future: fade out, particle burst, etc.
	pass

func get_depression_at_x(global_x: float) -> float:
	## Returns the virtual depression depth at a given X coordinate
	## Used by water system to report accurate height including whirlpool effect
	## Returns positive value = how much lower the water should appear
	var distance_from_center_x = abs(global_x - center_point.x)
	
	if distance_from_center_x > core_radius:
		return 0.0  # Outside whirlpool influence
	
	# Depression falls off smoothly from center
	var falloff = 1.0 - (distance_from_center_x / core_radius)
	falloff = falloff * falloff  # Quadratic for smooth cone shape
	
	return DEPRESSION_DEPTH * falloff

func _setup_depression_targets() -> void:
	## Calculate target rest heights (called once on spawn)
	## Actual application happens gradually in _update_water_depression
	if not water_node:
		return
	
	# Store original rest heights for reference (all should be surface_pos_y initially)
	# Actual modification happens gradually in _update_water_depression
	pass

func _update_water_depression(delta: float) -> void:
	## Set rest heights ONCE and let spring system settle naturally
	## Don't fight the spring physics by manipulating heights directly
	if not water_node:
		print("[Whirlpool] No water node found!")
		return
	
	if depression_applied:
		return  # Already set, let springs do their job
	
	var segment_count = water_node.segment_count
	var segment_width = water_node.water_size.x / (segment_count - 1)
	var water_local_center = water_node.to_local(center_point)
	var center_segment_index = int(clamp(water_local_center.x / segment_width, 0, segment_count - 1))
	
	# Calculate influence radius in segments
	var influence_radius_segments = int(core_radius / segment_width) + 2
	
	print("[Whirlpool] Applying depression instantly at segment ", center_segment_index)
	
	for offset in range(-influence_radius_segments, influence_radius_segments + 1):
		var segment_idx = center_segment_index + offset
		if segment_idx < 0 or segment_idx >= segment_count:
			continue
		
		# Calculate distance-based depression
		var distance_from_center = abs(offset * segment_width)
		var falloff = 1.0 - clamp(distance_from_center / core_radius, 0.0, 1.0)
		falloff = falloff * falloff  # Quadratic for smooth cone
		
		# Set final rest height immediately
		var target_rest_height = water_node.surface_pos_y + (DEPRESSION_DEPTH * falloff)
		water_node.segment_rest_height[segment_idx] = target_rest_height
		
		# DON'T touch height or velocity - let spring physics handle it
	
	depression_applied = true
	print("[Whirlpool] Depression rest heights set! Center target=", water_node.segment_rest_height[center_segment_index])
	
	# Keep water physics awake so it settles to new rest heights
	water_node.recently_splashed = true
	water_node.set_process(true)

func _find_water_node() -> void:
	## Find the water node this whirlpool is in (uses existing "water" group)
	var water_nodes = get_tree().get_nodes_in_group("water")
	
	for node in water_nodes:
		# Check if whirlpool is within this water's bounds
		var local_pos = node.to_local(global_position)
		if local_pos.x >= 0 and local_pos.x <= node.water_size.x:
			if local_pos.y >= node.surface_pos_y and local_pos.y <= node.water_size.y:
				water_node = node
				return
