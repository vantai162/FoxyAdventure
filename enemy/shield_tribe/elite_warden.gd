extends ShieldTribe
class_name EliteWarden
## Elite Shield Tribe: "The Warden"
## Shadow-stepping sentinel that teleports to intercept player
## Alternates between frontal blocking and rear flanking positions
## Cannot walk - only teleports (respects stationary nature)

@export_group("Teleportation")
@export var teleport_cooldown: float = 2.8  ## Balanced: Escapable but maintains pressure
@export var teleport_range_min: float = 80.0  ## Don't teleport if already very close
@export var teleport_range_max: float = 280.0  ## Won't teleport beyond this distance
@export var intercept_distance: float = 64.0  ## Distance ahead/behind player (2 tiles)
@export var teleport_detection_radius: float = 211.0  ## Double base detection (105.72 * 2)
@export var attack_detection_radius: float = 105.0  ## Same as base Shield Tribe for attack

@export_group("Enhanced Stats")
@export var first_attack_interval: float = 0.5  ## Ambush bonus after teleport (faster than normal 0.8s)

## Teleport state tracking
var last_teleport_time: float = -999.0  ## Can teleport immediately on spawn
var teleport_to_front: bool = true  ## Alternates: true=block, false=flank (starts with block)
var has_teleported_once: bool = false  ## Track if first teleport happened (for ambush bonus)

func _ready() -> void:
	# Initialize FSM with teleport state
	fsm = FSM.new(self, $States, $States/Idle)
	super._ready()
	
	# Override detection to use wider radius (set in scene's DetectPlayerArea2D)
	enable_check_player_in_sight()

func can_teleport() -> bool:
	## Check if enough time passed since last teleport
	if not found_player:
		return false
	
	var time_since_teleport = Time.get_ticks_msec() / 1000.0 - last_teleport_time
	if time_since_teleport < teleport_cooldown:
		return false
	
	# Check distance requirements
	var dist = global_position.distance_to(found_player.global_position)
	if dist < teleport_range_min or dist > teleport_range_max:
		return false
	
	return true

func mark_teleport_used() -> void:
	## Called when teleport completes
	last_teleport_time = Time.get_ticks_msec() / 1000.0
	has_teleported_once = true
	
	# Flip teleport pattern for next time (block -> flank -> block -> flank)
	teleport_to_front = not teleport_to_front

func get_teleport_destination() -> Vector2:
	## Calculate destination based on alternating pattern
	if not found_player:
		return global_position
	
	var player_pos = found_player.global_position
	var player_facing = 1  # Default right
	
	# Determine player's facing direction (use velocity if moving, else use sprite direction)
	if abs(found_player.velocity.x) > 10:
		player_facing = sign(found_player.velocity.x)
	elif found_player.has_method("get_direction"):
		player_facing = found_player.direction
	
	var offset_direction: int
	
	if teleport_to_front:
		# BLOCK: Teleport in front of player (blocks their path)
		offset_direction = player_facing
	else:
		# FLANK: Teleport behind player (rear attack)
		offset_direction = -player_facing
	
	var destination = player_pos + Vector2(offset_direction * intercept_distance, 0)
	
	# Ground validation (check if there's ground below destination)
	var ground_check = _find_nearest_ground(destination)
	if ground_check != Vector2.ZERO:
		return ground_check
	
	return destination

func _find_nearest_ground(pos: Vector2) -> Vector2:
	## Raycast down to find ground, adjust Y position if needed
	## NO wall check - can teleport through walls for horror factor!
	## Accounts for feet position at Y=30 in sprite to prevent clipping
	const FEET_OFFSET_Y = 30.0  # Feet position in sprite coordinates
	
	var space_state = get_world_2d().direct_space_state
	var ray_length = 64.0  # Check up to 64px below
	
	# Check for ground below destination
	var query = PhysicsRayQueryParameters2D.create(
		pos,
		pos + Vector2(0, ray_length),
		1  # Ground collision layer
	)
	
	var result = space_state.intersect_ray(query)
	if result:
		# Ground found - place feet exactly on ground surface
		return Vector2(pos.x, result.position.y - FEET_OFFSET_Y)
	
	# No ground found - try checking UPWARD (in case player is below)
	var up_query = PhysicsRayQueryParameters2D.create(
		pos,
		pos + Vector2(0, -ray_length),
		1
	)
	var up_result = space_state.intersect_ray(up_query)
	if up_result:
		# Ceiling found - place feet on ceiling (reverse gravity scenario)
		return Vector2(pos.x, up_result.position.y - FEET_OFFSET_Y)
	
	# Absolutely no ground - fallback fails gracefully
	return Vector2.ZERO

func should_trigger_teleport() -> bool:
	## Called by Idle/Defend states to check if should teleport
	## Only teleport when player detected and cooldown ready
	if not found_player:
		return false
	
	if not can_teleport():
		return false
	
	# Don't teleport during attack (committed)
	if fsm.current_state and fsm.current_state.name == "attack":
		return false
	
	return true

func get_ambush_attack_interval() -> float:
	## Return faster attack interval for first attack after teleport
	if has_teleported_once and Time.get_ticks_msec() / 1000.0 - last_teleport_time < 1.5:
		return first_attack_interval
	return attack_interval

# Override player detection - dual range detection (teleport far, attack close)
func _on_player_in_sight(_player_pos: Vector2) -> void:
	if not found_player:
		return
	
	var distance_to_player = global_position.distance_to(found_player.global_position)
	
	# Outer ring: Teleport detection (double base range)
	if distance_to_player <= teleport_detection_radius:
		# Can teleport, prefer teleporting over defending
		if should_trigger_teleport() and fsm.states.has("teleport"):
			fsm.change_state(fsm.states.teleport)
			return
	
	# Inner ring: Attack detection (base range, same as normal Shield Tribe)
	if distance_to_player <= attack_detection_radius:
		# Close enough for standard defend behavior
		super._on_player_in_sight(_player_pos)
		return
	
	# In between rings: Detected but out of attack range, just track player
	# Don't trigger anything, just stay aware

func _on_player_not_in_sight() -> void:
	# Return to idle when player leaves range
	if fsm and fsm.current_state:
		var state_name = fsm.current_state.name
		if state_name == "defend" or state_name == "attack":
			attack_timer.stop()
			fsm.change_state(fsm.states.idle)
