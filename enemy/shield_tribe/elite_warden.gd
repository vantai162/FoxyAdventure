extends EnemyCharacter
class_name EliteWarden
## Elite Shield Tribe: "The Warden"
## Shadow-stepping sentinel that teleports to intercept player
## Alternates between frontal blocking and rear flanking positions
## Cannot walk - only teleports (respects stationary nature)

@export_group("Combat - Shield Tribe Base")
@export var spear_damage: int = 2  ## Elite deals more damage
@export var attack_interval: float = 0.8  ## Fast threat response
@export var spear_thrust_distance: float = 96.0  ## Elite has longer reach
@export var spear_thrust_out_time: float = 0.6  ## Time to thrust out (synced with scene)
@export var spear_hold_time: float = 0.6  ## Time to hold extended

# Calculated total attack duration (read-only)
var attack_animation_duration: float:
	get:
		return spear_thrust_out_time + spear_hold_time

@export_group("Defense - Shield Tribe Base")
@export var jump_react_range: float = 60.0
@export var jump_react_velocity_threshold: float = -100.0
@export var jump_cooldown: float = 1.0
@export var block_jump_speed: float = 480.0  ## Elite jumps higher
@export var sight_range: float = 85.0
@export var turn_delay: float = 0.25  ## Elite turns faster

@export_group("Teleportation")
@export var teleport_cooldown: float = 2.8  ## Balanced: Escapable but maintains pressure
@export var teleport_range_min: float = 80.0  ## Don't teleport if already very close
@export var teleport_range_max: float = 280.0  ## Won't teleport beyond this distance
@export var intercept_distance: float = 64.0  ## Distance ahead/behind player (2 tiles)
@export var teleport_detection_radius: float = 211.0  ## Double base detection (105.72 * 2)
@export var attack_detection_radius: float = 105.0  ## Same as base Shield Tribe for attack

@export_group("Enhanced Stats")
@export var first_attack_interval: float = 0.5  ## Ambush bonus after teleport

## Shield Tribe nodes
@onready var shield: StaticBody2D = $Direction/Shield
@onready var spear: Node2D = $Direction/Spear
@onready var spear_sprite: AnimatedSprite2D = $Direction/Spear/AnimatedSprite2D
@onready var spear_hit_area: Area2D = $Direction/Spear/SpearHitArea
@onready var attack_timer: Timer = $AttackTimer

## Shield Tribe state
var _is_turning: bool = false
var _pending_direction: int = 0

## Teleport state tracking
var last_teleport_time: float = -999.0  ## Can teleport immediately on spawn
var teleport_to_front: bool = true  ## Alternates: true=block, false=flank (starts with block)
var has_teleported_once: bool = false  ## Track if first teleport happened (for ambush bonus)

func _ready() -> void:
	# Initialize FSM with teleport state (BEFORE super._ready)
	fsm = FSM.new(self, $States, $States/Idle)
	super._ready()
	
	# Initialize shield/spear
	shield.hide()
	shield.get_node("CollisionShape2D").disabled = true
	spear.hide()
	spear_hit_area.monitoring = false
	
	# Enable player detection
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
	
	# PRIORITY 1: Close range (≤105px) - Always defend/attack (like base behavior)
	if distance_to_player <= attack_detection_radius:
		# Within attack range - transition to defend state (Shield Tribe base behavior)
		if fsm and fsm.current_state and fsm.current_state.name != "defend" and fsm.current_state.name != "attack":
			fsm.change_state(fsm.states.defend)
		return
	
	# PRIORITY 2: Mid-range (105-211px) - Try teleport to close distance
	if distance_to_player <= teleport_detection_radius:
		# Outside attack range but within teleport detection
		# Try to teleport closer (if cooldown ready and conditions met)
		if should_trigger_teleport() and fsm.states.has("teleport"):
			fsm.change_state(fsm.states.teleport)
			return
		else:
			# Can't teleport (cooldown or conditions not met) - just stay in current state
			# This allows warden to wait patiently at distance
			pass
	
	# Beyond 211px shouldn't happen (Area2D won't detect), but just in case: do nothing

func _on_player_not_in_sight() -> void:
	# Return to idle when player leaves range
	if fsm and fsm.current_state:
		var state_name = fsm.current_state.name
		if state_name == "defend" or state_name == "attack":
			attack_timer.stop()
			fsm.change_state(fsm.states.idle)

# === SHIELD TRIBE FUNCTIONALITY (copied from base, not inherited) ===

func _on_hurt_area_2d_hurt(attack_direction: Vector2, damage: float) -> void:
	# BLOCKING LOGIC - Shield blocks attacks from front
	if fsm and fsm.current_state and fsm.current_state.name != "hurt" and fsm.current_state.name != "dead":
		var attack_side = sign(attack_direction.x)
		if attack_side == 0:
			attack_side = 1
		
		# Block if attack travels in opposite direction from our facing
		if attack_side != direction:
			# Wake up to defend if idle
			if fsm and fsm.current_state and fsm.current_state.name == "idle":
				fsm.change_state(fsm.states.defend)
			return  # BLOCKED - no damage
	
	# Not blocked → take damage
	_take_damage_from_dir(attack_direction, damage)

func face_player() -> void:
	# Don't turn during attack
	if fsm and fsm.current_state and fsm.current_state.name == "attack":
		return
		
	if found_player:
		var desired: int = 1 if found_player.global_position.x > global_position.x else -1

		if desired == direction:
			return

		if _is_turning:
			_pending_direction = desired
			return

		_is_turning = true
		_pending_direction = desired
		var t = get_tree().create_timer(turn_delay)
		t.timeout.connect(Callable(self, "_on_turn_timeout"))

func _on_turn_timeout() -> void:
	# Don't turn during attack
	if fsm.current_state.name == "attack":
		_pending_direction = 0
		_is_turning = false
		return
	
	if _pending_direction != 0:
		change_direction(_pending_direction)
	_pending_direction = 0
	_is_turning = false

func perform_spear_attack() -> void:
	spear.show()
	spear_sprite.play("attack")
	
	var spear_start_pos = spear.position
	spear_hit_area.monitoring = true
	
	var tween = create_tween()
	tween.tween_property(spear, "position", spear_start_pos + Vector2(spear_thrust_distance, 0), spear_thrust_out_time)
	tween.tween_interval(spear_hold_time)
	tween.tween_callback(func(): 
		spear_hit_area.monitoring = false
		spear.hide()
		spear.position = spear_start_pos
	)

func show_shield() -> void:
	shield.show()
	shield.get_node("CollisionShape2D").disabled = false

func hide_shield() -> void:
	shield.hide()
	shield.get_node("CollisionShape2D").disabled = true

func darken_shield() -> void:
	# Shield visual is baked into AnimatedSprite2D - no separate sprite to darken
	pass

func restore_shield_color() -> void:
	# Shield visual is baked into AnimatedSprite2D - no separate sprite to restore
	pass
