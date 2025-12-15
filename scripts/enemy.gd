class_name EnemyCharacter
extends BaseCharacter

## === BURN STATUS ===
## Enemies hit by flame blade burn for damage over time.
## Simple, no-fuss implementation: timer + tick damage.
var is_burning: bool = false
var burn_timer: float = 0.0
var burn_tick_timer: float = 0.0
const BURN_DURATION: float = 3.0      ## Seconds of burning
const BURN_TICK_RATE: float = 0.5     ## Damage every X seconds
const BURN_DAMAGE: int = 1            ## Damage per tick

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


## === BURN STATUS EFFECTS ===

## Set this enemy on fire. Called by flame blade projectile.
func ignite() -> void:
	is_burning = true
	burn_timer = BURN_DURATION
	burn_tick_timer = 0.0  # Immediate first tick
	
	# Create burn particles if not already present
	if burn_particles == null:
		_create_burn_particles()
	burn_particles.emitting = true

## Update burn status each frame
func _update_burn(delta: float) -> void:
	if not is_burning:
		return
	
	burn_timer -= delta
	burn_tick_timer -= delta
	
	# Apply burn damage on tick
	if burn_tick_timer <= 0:
		burn_tick_timer = BURN_TICK_RATE
		# Use base take_damage to avoid triggering hurt state repeatedly
		health -= BURN_DAMAGE
		if health <= 0:
			# Let the FSM handle death properly
			if fsm and fsm.current_state:
				fsm.current_state.take_damage(Vector2.ZERO, 0)
	
	# Burn expired
	if burn_timer <= 0:
		is_burning = false
		if burn_particles:
			burn_particles.emitting = false

## Create GPU-native fire particles for burning effect
## Uses preloaded scene — zero runtime construction, GPU-rendered
func _create_burn_particles() -> void:
	burn_particles = BURN_PARTICLES_SCENE.instantiate()
	burn_particles.name = "BurnParticles"
	burn_particles.emitting = false
	add_child(burn_particles)