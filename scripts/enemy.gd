class_name EnemyCharacter
extends BaseCharacter

## === BURN STATUS (Kojima-Balanced) ===
## Enemies hit by flame blade burn for damage over time.
## Design philosophy: Flame blade is a POWER, not a CHEAT.
##   - It adds value (bonus tick damage) without trivializing combat
##   - Regular mobs: 1 bonus damage over time (not instant kills)
##   - Bosses: Reduced effect with resistance multipliers
##   - Still requires player skill to hit and survive
##
## Balance math for 2 HP enemy (crab/turtle):
##   - Blade hit: 1 damage → 1 HP left
##   - Burn: 1 tick after 1s → dead
##   - Total: 2 damage over 1.5s (player must survive that window)
##   - Without flame: 2 hits required (same result, flame saves 1 hit)
##
## Balance math for 3 HP enemy:
##   - Blade hit: 1 damage → 2 HP left  
##   - Burn: 1 tick → 1 HP left
##   - Blade hit: 1 damage → dead
##   - Total: 3 damage (flame saves 1 hit, still need 2 blade hits)

var is_burning: bool = false
var burn_timer: float = 0.0
var burn_tick_timer: float = 0.0
var burn_cooldown: float = 0.0  ## Prevents re-ignite spam for instant ticks

## Burn parameters — can be overridden by boss/elite subclasses
@export_group("Burn Resistance")
@export var burn_duration_multiplier: float = 1.0  ## <1.0 = shorter burn (boss resistance)
@export var burn_damage_multiplier: float = 1.0    ## <1.0 = less damage per tick
@export var burn_immune: bool = false              ## Full immunity (optional)

## === BALANCED BURN CONSTANTS ===
## Philosophy: Burn = 1 BONUS damage, not a flamethrower massacre
const BASE_BURN_DURATION: float = 1.5   ## 1.5s burn (was 3s — too long)
const BURN_TICK_RATE: float = 1.0       ## 1 tick per second (was 0.5s — too fast)
const BASE_BURN_DAMAGE: int = 1         ## 1 damage per tick (unchanged)
const BURN_REIGNITE_COOLDOWN: float = 2.0  ## Can't re-ignite for 2s (was 1s)
## Result: 1-2 ticks max = 1-2 bonus damage per ignite (not 6-7)

## GPU-native burn particles — preloaded, not procedurally built
const BURN_PARTICLES_SCENE: PackedScene = preload("res://assets/effects/burn_particles.tscn")
var burn_particles: GPUParticles2D = null  ## Visual effect (instantiated on first burn)

# Raycast check wall and fall
var front_ray_cast: RayCast2D;
var down_ray_cast: RayCast2D;
@export var knockback_force: float = 150
# detect player area
var detect_player_area: Area2D;
var found_player: Player = null
var detect_ray_cast:RayCast2D;
var detect_ray_casts: Array[RayCast2D] = []  # Multiple raycasts for vision cone
var detection_distance: float = 100.0

func _ready() -> void:
	# Add to enemy group for player targeting system
	add_to_group("enemy")
	
	_init_ray_cast()
	_init_detect_player_area()
	_init_hurt_area()
	super._ready()
	movement_speed = 100
	pass


#init ray cast to check wall and fall
func _init_ray_cast():
	if has_node("Direction/FrontRayCast2D"):
		front_ray_cast = $Direction/FrontRayCast2D
	if has_node("Direction/DownRayCast2D"):
		down_ray_cast = $Direction/DownRayCast2D
	if has_node("Direction/DetectPlayerRayCast2D"):
		detect_ray_cast = $Direction/DetectPlayerRayCast2D
		detect_ray_casts.append(detect_ray_cast)
	
	# Collect additional detection raycasts for vision cone (if they exist)
	for i in range(1, 5):  # Support up to 4 additional raycasts
		var ray_name = "Direction/DetectPlayerRayCast2D" + str(i)
		if has_node(ray_name):
			var ray = get_node(ray_name) as RayCast2D
			detect_ray_casts.append(ray)


#init detect player area
func _init_detect_player_area():
	if has_node("Direction/DetectPlayerArea2D"):
		detect_player_area = $Direction/DetectPlayerArea2D
		detect_player_area.body_entered.connect(_on_body_entered)
		detect_player_area.body_exited.connect(_on_body_exited)
		
		# CRITICAL: Check for initial overlaps (player spawned inside detection radius)
		# Area2D signals only fire on state CHANGES, not initial overlaps
		# Must be deferred because collision detection isn't ready in _ready()
		call_deferred("_check_initial_overlap")
		

func _physics_process(delta: float) -> void:
	# keep your original BaseCharacter physics
	super._physics_process(delta)
	# only add this lightweight detection pass
	_check_player_in_sight()
	# Burn status tick
	_update_burn(delta)

# init hurt area
func _init_hurt_area():
	if has_node("Direction/HurtArea2D"):
		var hurt_area = $Direction/HurtArea2D
		hurt_area.hurt.connect(_on_hurt_area_2d_hurt)

# check touch wall (ignores one-way platforms)
func is_touch_wall() -> bool:
	if front_ray_cast != null and front_ray_cast.is_colliding():
		var collider = front_ray_cast.get_collider()
		if collider:
		# Ignore one-way platforms - enemies should walk over them
			if collider.is_in_group("one_way_platform"):
				return false
			else:
				return true
	return false

# check can fall
func is_can_fall() -> bool:
	if down_ray_cast != null:
		return not down_ray_cast.is_colliding()
	return false

#enable check player in sight
func enable_check_player_in_sight() -> void:
	
	if(detect_player_area != null):
		detect_player_area.get_node("CollisionShape2D").disabled = false
	if detect_ray_cast != null:
		detect_ray_cast.enabled = true
	# Enable all vision cone raycasts
	for ray in detect_ray_casts:
		if ray != null:
			ray.enabled = true

#disable check player in sight
func disable_check_player_in_sight() -> void:
	if(detect_player_area != null):
		detect_player_area.get_node("CollisionShape2D").disabled = true
	if detect_ray_cast != null:
		detect_ray_cast.enabled = false
	# Disable all vision cone raycasts
	for ray in detect_ray_casts:
		if ray != null:
			ray.enabled = false
	if found_player != null:
		found_player = null
		_on_player_not_in_sight()

func _on_body_entered(_body: CharacterBody2D) -> void:
	found_player = _body
	_on_player_in_sight(_body.global_position)

func _on_body_exited(_body: CharacterBody2D) -> void:
	found_player = null
	_on_player_not_in_sight()

func _check_initial_overlap() -> void:
	## Check if player is already inside detection area on spawn
	## Fixes bug where player spawning inside Area2D doesn't trigger body_entered signal
	if detect_player_area == null:
		return
	
	var overlapping_bodies = detect_player_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body is Player:
			# Manually trigger detection as if body_entered fired
			found_player = body
			_on_player_in_sight(body.global_position)
			break

func _on_hurt_area_2d_hurt(_direction: Vector2, _damage: float) -> void:
	# Face the attacker if hit from behind
	# Direction points FROM attacker TO us, so we need to face the OPPOSITE direction
	if _direction.x != 0:
		var attacker_side = -sign(_direction.x)  # Negate to get attacker's position
		# If we're facing away from the attacker, turn around immediately
		if attacker_side != direction:
			change_direction(attacker_side)
	
	_take_damage_from_dir(_direction, _damage)

# called when player is in sight
func _on_player_in_sight(_player_pos: Vector2):
	#fsm.current_state.change_state(fsm.states.surprise)
	pass
	
func is_player_in_sight() -> bool:
	if detect_ray_cast != null:
		return detect_ray_cast.is_colliding()
	return false


# called when player is not in sight
func _on_player_not_in_sight():
	pass

func _take_damage_from_dir(_damage_dir: Vector2, _damage: float):
	# Can't take damage if FSM isn't initialized yet (lazy-loaded enemies)
	if fsm == null:
		return
	# Can't take damage if current_state is null (during transitions or after death)
	if fsm.current_state == null:
		return
	if not invincible:
		fsm.current_state.take_damage(_damage_dir, _damage)
	
func check_player_in_sight(player: Player) -> bool:
	if detect_ray_cast == null:
		return false

	# Hướng ray theo hướng enemy đang nhìn
	var dir = Vector2.RIGHT * (1 if direction > 0 else -1)
	var from = global_position
	var to = from + dir * detection_distance

	# Sử dụng trực tiếp RayCast2D hoặc PhysicsRayQuery
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from, to)
	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return false

	var collider = result["collider"]
	if collider is Player:
		return true

	return false

func _check_player_in_sight() -> void:
	if detect_ray_casts.is_empty():
		return
	
	# Check if any raycast in the vision cone detects the player
	var player_detected = false
	var detected_player: Player = null
	
	
	for ray in detect_ray_casts:
		if ray == null or not ray.enabled:
			continue
			
		if ray.is_colliding():
			var collider = ray.get_collider()
			if collider is Player:
				player_detected = true
				detected_player = collider
				break
	
	# Update found_player state
	if player_detected:
		if found_player == null:
			found_player = detected_player
			_on_player_in_sight(detected_player.global_position)
	else:
		if found_player != null:
			found_player = null
			_on_player_not_in_sight()


## === BURN STATUS EFFECTS (Kojima-Balanced) ===

## Set this enemy on fire. Called by flame blade projectile.
## Respects burn immunity and cooldown to prevent exploit spam.
func ignite() -> void:
	# Full immunity check (bosses can opt out entirely)
	if burn_immune:
		return
	
	# Cooldown prevents re-ignite spam for instant tick abuse
	if burn_cooldown > 0.0:
		return  # Already burning, can't refresh yet
	
	# Calculate actual burn duration with resistance
	var actual_duration = BASE_BURN_DURATION * burn_duration_multiplier
	
	is_burning = true
	burn_timer = actual_duration
	burn_tick_timer = BURN_TICK_RATE  # DELAYED first tick — no instant damage
	burn_cooldown = BURN_REIGNITE_COOLDOWN  # Prevent re-ignite spam
	
	# Create burn particles if not already present
	if burn_particles == null:
		_create_burn_particles()
	burn_particles.emitting = true

## Update burn status each frame
## Respects invincibility and flows through proper damage systems.
func _update_burn(delta: float) -> void:
	# Tick cooldown even when not burning (prevents ignite spam)
	if burn_cooldown > 0.0:
		burn_cooldown -= delta
	
	if not is_burning:
		return
	
	burn_timer -= delta
	burn_tick_timer -= delta
	
	# Apply burn damage on tick
	if burn_tick_timer <= 0:
		burn_tick_timer = BURN_TICK_RATE
		
		# === RESPECT INVINCIBILITY ===
		# Kojima's Law: Every system respects every other system
		if invincible:
			# Still burning visually, but no damage while invincible
			# This prevents cheese through attack animations
			return
		
		# Calculate actual damage with resistance
		var actual_damage = int(ceil(BASE_BURN_DAMAGE * burn_damage_multiplier))
		if actual_damage <= 0:
			return  # Full damage resistance
		
		# === FLOW THROUGH PROPER DAMAGE SYSTEM ===
		# This triggers:
		#   - Boss's take_damage() override (health bar, audio, phase transitions)
		#   - Proper death handling
		#   - Any subclass-specific logic
		take_damage(actual_damage)
		
		# === BURN TICK FEEDBACK ===
		# Small flash to show damage is happening (without full hurt animation)
		_burn_tick_feedback()
	
	# Burn expired
	if burn_timer <= 0:
		is_burning = false
		if burn_particles:
			burn_particles.emitting = false

## Visual feedback for burn tick damage — subtle flash without full hurt animation
## Kojima's Law: The player must FEEL the impact of their actions
func _burn_tick_feedback() -> void:
	# Quick red-orange flash on the sprite
	if animated_sprite == null:
		return
	
	# Create a quick tween for the flash
	var flash_tween = create_tween()
	flash_tween.tween_property(animated_sprite, "modulate", Color(1.5, 0.7, 0.5, 1.0), 0.05)
	flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)

## Create GPU-native fire particles for burning effect
## Uses preloaded scene — zero runtime construction, GPU-rendered
func _create_burn_particles() -> void:
	burn_particles = BURN_PARTICLES_SCENE.instantiate()
	burn_particles.name = "BurnParticles"
	burn_particles.emitting = false
	add_child(burn_particles)