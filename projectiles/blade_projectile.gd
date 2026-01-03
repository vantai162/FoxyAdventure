extends Area2D
class_name BladeProjectile

enum State { FLYING, BOUNCED, GROUNDED }

var current_state: State = State.FLYING
var velocity: Vector2 = Vector2.ZERO
var damage: int = 1

# === FLIGHT PARAMETERS ===
@export_group("Flight")
@export var initial_throw_speed: float = 400.0
@export var max_flight_distance: float = 300.0
@export_range(0.0, 1.0, 0.05) var speed_after_max_distance: float = 0.6

@export_group("Ricochet")
@export_range(0.0, 1.0, 0.05) var bounce_energy_retention: float = 0.4
@export var first_bounce_upward_force: float = 300.0
@export_range(0.0, 1.0, 0.05) var close_bounce_speed_multiplier: float = 0.5
@export_range(0.0, 1.0, 0.05) var far_bounce_speed_multiplier: float = 0.4
@export_range(-1.0, 0.0, 0.1) var first_bounce_upward_angle: float = -0.5

@export_group("Visual")
@export var rotation_speed_flying: float = 10.0
@export var rotation_speed_bouncing: float = 20.0
@onready var fire_particles = $FireParticles
@onready var blade_light: PointLight2D = $Light
var light_base_energy := 0.0
var light_flicker_tween: Tween
@export var light_flicker_enabled := true
@export var light_flicker_speed := 12.0
@export var light_flicker_intensity := 0.12

@export_subgroup("Motion Blur Trail")
@export var trail_enabled: bool = true
@export var trail_texture: Texture2D  ## The blade sprite for trail ghosts
@export var trail_spawn_rate: float = 0.05  ## Seconds between ghost spawns
@export var trail_ghost_fade_time: float = 0.25  ## Fade out duration
@export var trail_minimum_speed: float = 50.0  ## Minimum speed to show trail
@export var trail_pool_size: int = 8  ## Pre-allocated ghost sprites

## Trail system: Object pool of ghost sprites (no runtime allocation)
var trail_pool: Array[Sprite2D] = []
var trail_pool_index: int = 0
var trail_spawn_timer: float = 0.0

@export_group("Grounded")
@export var pickup_delay_seconds: float = 6.5
@export var grounded_glow_color: Color = Color(1.2, 1.1, 0.7, 1.0)  ## Subtle warm highlight (was 1.5, 1.3, 0.5 - too saturated)
@export var glow_blink_speed: float = 3.0  ## Speed of blink effect (was 4.0)
@export var glow_off_brightness: float = 1.0  ## Brightness when "off" (normal sprite)
@export var glow_on_brightness: float = 1.3  ## Brightness when "on" (was 2.5 - flashbang territory)

@export_group("Safety")
@export var void_y_threshold: float = 2000.0  ## Return blade if it falls below this Y position
@export var max_bounced_time: float = 10.0  ## Max seconds in BOUNCED state before auto-return

@export_group("Magnetism")
@export var magnet_enabled: bool = true
@export var magnet_range_grounded: float = 120.0  ## Pull range when blade is on ground
@export var magnet_range_airborne: float = 80.0  ## Pull range when blade is airborne (bouncing)
@export var magnet_strength_grounded: float = 800.0  ## Pull force when on ground
@export var magnet_strength_airborne: float = 400.0  ## Pull force when airborne
@export var intent_threshold: float = 50.0  ## Minimum player speed towards blade to trigger magnetism

# Internal state
var distance_traveled: float = 0.0
var thrower: Player = null
var throw_direction: int = 1
var glow_time: float = 0.0  # For pulsing glow effect
var bounced_time: float = 0.0  # Time spent in BOUNCED state

## === LOYALTY SYSTEM ===
## The fox's first blade is blood-bound — it ALWAYS returns to him.
## Subsequent blades are expendable — only the LAST thrown one returns.
## Orphaned blades (thrown before the current active) expire if not manually picked up.
var is_loyal: bool = false:  ## Blood-bound blade: always returns, never lost
	set(value):
		is_loyal = value
		if is_loyal:
			_apply_loyal_visual()
		else:
			_remove_loyal_visual()
var is_active: bool = true  ## Only active blade auto-returns; orphans expire on timeout

## GPU-native loyal glow — preloaded, not procedurally built
const LOYAL_GLOW_SCENE: PackedScene = preload("res://assets/effects/loyal_glow.tscn")
var loyal_glow: PointLight2D = null  ## Ethereal glow for the blood-bound blade

## === SATISFACTION FEEDBACK SCENES (GPU-native, preloaded) ===
const RICOCHET_SPARKS_SCENE: PackedScene = preload("res://assets/effects/ricochet_sparks.tscn")
const STEAM_BURST_SCENE: PackedScene = preload("res://assets/effects/steam_burst.tscn")
const DUST_PUFF_SCENE: PackedScene = preload("res://assets/effects/dust_puff.tscn")
const RUST_FLAKES_SCENE: PackedScene = preload("res://assets/effects/rust_flakes.tscn")

@onready var ground_timer: Timer = $GroundTimer
@onready var hit_area: Area2D = $HitArea2D
@onready var spinning_sprite: Sprite2D = $Sprite2D
@onready var landed_sprite: Sprite2D = $Sprite2D2
@onready var grounded_light: PointLight2D = $GroundedGlow if has_node("GroundedGlow") else null

## Flame blade state - can be extinguished by water
var is_flame_active: bool = false

## Single source of truth for which sprite is currently active
## Prevents state desync when applying modulate/effects to the wrong sprite
func _get_active_sprite() -> Sprite2D:
	return landed_sprite if current_state == State.GROUNDED else spinning_sprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# Initialize trail ghost pool (no runtime allocation)
	_init_trail_pool()
	
	# Initialize flame state from player unlock
	is_flame_active = GameManager.player.has_unlocked_flame_blade
	fire_particles.emitting = is_flame_active
	
	light_base_energy = blade_light.energy
	blade_light.enabled = is_flame_active
	if is_flame_active:
		_start_light_flicker()
	
	# Connect hit_area signal to apply burn on hit
	if hit_area.has_signal("hitted"):
		hit_area.hitted.connect(_on_hit_area_hit)
	
	# Only set if not already configured in editor
	if ground_timer.wait_time == 0:
		ground_timer.wait_time = pickup_delay_seconds
	if not ground_timer.one_shot:
		ground_timer.one_shot = true
	ground_timer.timeout.connect(_on_ground_timer_timeout)
	
	if hit_area.damage == 0:
		hit_area.damage = damage

## Initialize trail ghost pool — all allocation happens once at spawn
## Ghosts are parented to the blade with top_level=true for world-space rendering.
## This ensures automatic cleanup when blade is freed — no orphan risk on scene change.
func _init_trail_pool() -> void:
	if not trail_enabled or not trail_texture:
		return
	
	for i in range(trail_pool_size):
		var ghost = Sprite2D.new()
		ghost.texture = trail_texture
		ghost.visible = false
		ghost.z_index = z_index - 1
		ghost.top_level = true  # Renders in world space, not relative to blade
		add_child(ghost)  # Parented to blade — freed automatically with blade
		trail_pool.append(ghost)

## Cleanup trail pool when blade is destroyed
## Note: With top_level parenting, ghosts are children of blade and auto-freed.
## This explicit cleanup kills any running tweens to prevent orphan callbacks.
func _exit_tree() -> void:
	for ghost in trail_pool:
		if is_instance_valid(ghost):
			# Kill any running tween to prevent orphan callbacks
			if ghost.has_meta("_trail_tween"):
				var tween = ghost.get_meta("_trail_tween")
				if tween and tween.is_valid():
					tween.kill()
			# No need to queue_free — Godot auto-frees children
	trail_pool.clear()

func launch(direction: int, from_player: Player) -> void:
	thrower = from_player
	throw_direction = direction
	velocity = Vector2(direction * initial_throw_speed, 0)
	scale.x = direction
	current_state = State.FLYING
	if GameManager.player.has_unlocked_flame_blade:
		blade_light.enabled = true
		_start_light_flicker()
	AudioManager.play_sound("blade_spinning",15.0)


## Aimed throw - launches blade at a specific angle (radians)
## Used by targeting system for smart throws at enemies
func launch_aimed(angle: float, from_player: Player) -> void:
	thrower = from_player
	
	# Determine throw direction from angle (left or right hemisphere)
	if angle > PI / 2 or angle < -PI / 2:
		throw_direction = -1  # Left
	else:
		throw_direction = 1  # Right
	
	# Calculate velocity vector from angle
	velocity = Vector2.from_angle(angle) * initial_throw_speed
	scale.x = throw_direction
	current_state = State.FLYING
	if GameManager.player.has_unlocked_flame_blade:
		blade_light.enabled = true
		_start_light_flicker()
	AudioManager.play_sound("blade_spinning", 15.0)

func _physics_process(delta: float) -> void:
	match current_state:
		State.FLYING:
			_update_flying(delta)
		State.BOUNCED:
			_update_bounced(delta)
			_apply_magnetism(delta, magnet_range_airborne, magnet_strength_airborne)
		State.GROUNDED:
			_update_grounded_visual(delta)
			_apply_magnetism(delta, magnet_range_grounded, magnet_strength_grounded)
			return
	
	if trail_enabled:
		_update_trail(delta)

func _update_flying(delta: float) -> void:
	distance_traveled += velocity.length() * delta
	
	if distance_traveled >= max_flight_distance:
		_transition_to_arc_down()
		return
	
	position += velocity * delta
	rotation += rotation_speed_flying * delta * throw_direction

func _update_bounced(delta: float) -> void:
	# Safety: return blade if it's been bouncing too long or fell into void
	bounced_time += delta
	if bounced_time >= max_bounced_time or global_position.y > void_y_threshold:
		_auto_return_from_void()
		return
	
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	velocity.y += gravity * delta
	
	var motion = velocity * delta
	var lookahead_multiplier = 2.0
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + motion * lookahead_multiplier)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_normal = result.normal
		var hit_position = result.position
		
		if velocity.y > 0 and hit_normal.y < -0.7:
			global_position = hit_position - Vector2(0, 2)
			_transition_to_grounded()
			return
		else:
			global_position = hit_position + hit_normal * 2
			
			var bounced_velocity = velocity.bounce(hit_normal)
			
			if throw_direction > 0:
				bounced_velocity.x = min(bounced_velocity.x, -abs(bounced_velocity.x) * 0.5)
			else:
				bounced_velocity.x = max(bounced_velocity.x, abs(bounced_velocity.x) * 0.5)
			
			velocity = bounced_velocity * bounce_energy_retention
			return
	
	position += motion
	rotation += rotation_speed_bouncing * delta * throw_direction

func _update_trail(delta: float) -> void:
	## Object-pooled trail: crisp blade sprite ghosts with rotation
	## No allocation, no queue_free — pool recycles automatically
	if not trail_enabled or trail_pool.is_empty():
		return
	
	var speed = velocity.length()
	if speed < trail_minimum_speed:
		return
	
	trail_spawn_timer -= delta
	if trail_spawn_timer <= 0:
		trail_spawn_timer = trail_spawn_rate
		_spawn_trail_ghost()

func _spawn_trail_ghost() -> void:
	## Grab next ghost from pool (circular buffer)
	var ghost = trail_pool[trail_pool_index]
	trail_pool_index = (trail_pool_index + 1) % trail_pool_size
	
	## Kill any existing tween to prevent conflicts (ghost reused before fade complete)
	if ghost.has_meta("_trail_tween"):
		var old_tween = ghost.get_meta("_trail_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	
	## Snapshot current blade state — this is what makes the trail look RIGHT
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation  ## Captures spinning rotation!
	ghost.scale = scale
	ghost.modulate = Color(1, 1, 1, 0.6)
	ghost.visible = true
	
	## Fade out using tween (efficient — no per-frame script)
	var tween = ghost.create_tween()
	ghost.set_meta("_trail_tween", tween)
	tween.tween_property(ghost, "modulate:a", 0.0, trail_ghost_fade_time)
	tween.tween_callback(func(): ghost.visible = false)

func _apply_magnetism(delta: float, pull_range: float, pull_strength: float) -> void:
	if not magnet_enabled or not thrower:
		return
	
	var distance_to_player = global_position.distance_to(thrower.global_position)
	
	# Out of range, no magnetism
	if distance_to_player > pull_range:
		return
	
	# Check player intent: is player moving towards the blade?
	var direction_to_blade = (global_position - thrower.global_position).normalized()
	var player_velocity_towards_blade = thrower.velocity.dot(direction_to_blade)
	
	# Player must be moving towards blade at minimum speed to trigger magnetism
	if player_velocity_towards_blade < intent_threshold:
		return
	
	# Apply magnetic pull towards player
	var pull_direction = (thrower.global_position - global_position).normalized()
	var distance_factor = 1.0 - (distance_to_player / pull_range)  # Stronger when closer
	var pull_force = pull_direction * pull_strength * distance_factor * delta
	
	if current_state == State.GROUNDED:
		# Grounded blade pulls itself towards player
		global_position += pull_force
	elif current_state == State.BOUNCED:
		# Airborne blade adjusts velocity towards player
		velocity += pull_force * 60.0  # Scale up for velocity-based movement

func _update_grounded_visual(delta: float) -> void:
	## Blade is ~16px. The blade BREATHES while grounded — it's waiting, alive.
	## Organic sine-wave pulse instead of casino square-wave blink.
	if not landed_sprite.visible:
		return
	
	# Organic breathing pulse using sine wave
	glow_time += delta * glow_blink_speed
	var breath_cycle = sin(glow_time * TAU)  # -1 to 1 smooth oscillation
	var breath_normalized = (breath_cycle + 1.0) / 2.0  # 0 to 1
	
	# Smooth interpolation between dim and bright
	var brightness = lerpf(glow_off_brightness, glow_on_brightness, breath_normalized)
	var light_energy = lerpf(0.2, 0.5, breath_normalized)
	
	# Apply glow color with breathing brightness
	# Preserve loyal blade tint by multiplying rather than overwriting
	var base_tint = Color(0.8, 0.9, 1.0, 1.0) if is_loyal else Color.WHITE
	landed_sprite.modulate = grounded_glow_color * brightness * base_tint
	
	# GPU light glow breathes with the blade
	if grounded_light:
		grounded_light.energy = light_energy

func _transition_to_arc_down() -> void:
	current_state = State.BOUNCED
	bounced_time = 0.0
	velocity.x *= speed_after_max_distance
	velocity.y = 0

func _transition_to_ricochet() -> void:
	## The fox is a master blade-thrower. Every throw is intentional.
	## When the blade ricochets, it arcs BACK toward the thrower — not away.
	## This creates game feel: the fox doesn't chase his weapon; it returns to him.
	## Magnetism in BOUNCED state further guides the blade home.
	
	# === IMPACT FEEDBACK: The moment of contact MATTERS ===
	_spawn_ricochet_feedback()
	
	current_state = State.BOUNCED
	bounced_time = 0.0
	
	# Calculate bounce arc based on distance traveled (further = wider arc)
	var distance_ratio = distance_traveled / max_flight_distance
	var bounce_speed = initial_throw_speed * bounce_energy_retention * (
		close_bounce_speed_multiplier + distance_ratio * far_bounce_speed_multiplier
	)
	
	# Backward arc: blade reverses direction and arcs upward
	# -throw_direction = back toward thrower
	# first_bounce_upward_angle = upward bias (-0.5 = 30° up from horizontal)
	var backward_direction = Vector2(-throw_direction, first_bounce_upward_angle).normalized()
	velocity = backward_direction * bounce_speed
	velocity.y -= first_bounce_upward_force  # Extra upward kick for satisfying arc

func _transition_to_grounded() -> void:
	# === LANDING FEEDBACK: Blade embeds with weight ===
	_spawn_landing_feedback()
	
	current_state = State.GROUNDED
	velocity = Vector2.ZERO
	rotation = 0  # Orient blade upright
	collision_mask = 2  # Only detect player for pickup
	ground_timer.start()
	
	hit_area.monitoring = false
	spinning_sprite.visible = false
	landed_sprite.visible = true
	glow_time = 0.0  # Reset glow animation
	
	# Enable grounded glow light
	if grounded_light:
		grounded_light.visible = true

func _on_body_entered(body: Node) -> void:
	# Pickup by player
	if body == thrower:
		_pickup_by_player()
		return
	
	# Ricochet off ANY solid body during flight (walls, ground, enemies, shields)
	# The blade arcs back toward the fox — mastery, not physics
	if current_state == State.FLYING:
		_transition_to_ricochet()

func _on_area_entered(area: Area2D) -> void:
	# Pickup by player's HurtArea or other areas
	#if area.get_parent() == thrower:
	#	_pickup_by_player()
	#	return
	
	# Water extinguishes flame blade
	if area.is_in_group("water"):
		extinguish()
		return
	
	# Trigger interactable objects (levers, etc.) and ricochet
	if area.is_in_group("blade_interactable"):
		_trigger_interactable(area)
		# Ricochet: blade arcs back to thrower (mastery, not Newtonian physics)
		# The fox threw at this lever ON PURPOSE. He knows it'll come back.
		if current_state == State.FLYING:
			_transition_to_ricochet()

func _on_area_exited(area: Area2D) -> void:
	# Re-ignite flame when blade leaves water
	if area.is_in_group("water"):
		reignite()

func _trigger_interactable(area: Area2D) -> void:
	## Activate levers and other blade-interactable objects
	## Note: TimerLever was merged into Lever (use mode = TIMED)
	if area is Lever:
		area.activate()
	# Future: other interactables can be added here

func _pickup_by_player() -> void:
	## Player physically touches the blade — ALWAYS returns it to inventory.
	## This rewards the player for actively retrieving their blade.
	
	# === REWARD FEEDBACK: Satisfying blade return ===
	AudioManager.play_sound("blade_pickup", 12.0)
	_flash_and_shrink()
	
	if thrower and thrower.has_method("return_blade"):
		thrower.return_blade(is_loyal)
	# Note: queue_free happens after shrink tween completes

func _on_ground_timer_timeout() -> void:
	## Blade sat on ground too long without being picked up.
	## Loyal blade: blood-bound, ALWAYS returns (even if hands full — absorbs a scrap).
	## Scrap blade: just metal. No magic. Lost forever if not picked up.
	if is_loyal:
		# The blood-bound blade finds its way back (silent, magical)
		if thrower and thrower.has_method("return_blade"):
			thrower.return_blade(true)  # Force return — loyal blade never stranded
		queue_free()
	else:
		# === LOSS FEEDBACK: Expendable blade rusts away ===
		_rust_and_fade()

func _auto_return_from_void() -> void:
	## Safety net: blade fell into void or bounced too long.
	## Only the loyal blade has the magical bond to return.
	if is_loyal:
		if thrower and thrower.has_method("return_blade"):
			thrower.return_blade(true)  # Force return — loyal blade never lost
	# Scraps lost to the void are gone forever
	queue_free()
	
func _start_light_flicker():
	if not light_flicker_enabled:
		return

	if light_flicker_tween:
		light_flicker_tween.kill()

	light_flicker_tween = create_tween().set_loops()

	var duration = 1.0 / max(light_flicker_speed, 0.1)
	var high := light_base_energy + light_flicker_intensity
	var low := light_base_energy - light_flicker_intensity

	light_flicker_tween.tween_property(blade_light, "energy", high, duration * 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	light_flicker_tween.tween_property(blade_light, "energy", low, duration * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	light_flicker_tween.tween_property(blade_light, "energy", light_base_energy, duration * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _extinguish_light():
	if light_flicker_tween:
		light_flicker_tween.kill()


	var t = create_tween()
	t.tween_property(blade_light, "energy", 0.0, 0.1)
	blade_light.enabled = false


## === FLAME BLADE MECHANICS ===

## Called when blade hits an enemy's HurtArea2D
func _on_hit_area_hit(area: Area2D) -> void:
	if not is_flame_active:
		return
	
	# Find the enemy that owns this hurt area
	var parent = area.get_parent()
	if parent == null:
		parent = area.owner
	
	# Walk up to find EnemyCharacter
	while parent != null:
		if parent is EnemyCharacter:
			parent.ignite()
			return
		parent = parent.get_parent()

## Extinguish flame when entering water (temporary, visual feedback)
func extinguish() -> void:
	if not is_flame_active:
		return
	
	is_flame_active = false
	fire_particles.emitting = false
	_extinguish_light()
	
	# === EXTINGUISH FEEDBACK: Steam hiss + visual burst ===
	AudioManager.play_sound("steam_hiss", 10.0)
	_spawn_steam_burst()

## Re-ignite when leaving water (if player has flame upgrade)
func reignite() -> void:
	if not GameManager.player.has_unlocked_flame_blade:
		return
	
	is_flame_active = true
	fire_particles.emitting = true
	blade_light.enabled = true
	_start_light_flicker()
	
	# === REIGNITE FEEDBACK: Fwoosh + flash ===
	AudioManager.play_sound("flame_ignite", 8.0)
	_flash_sprite()


## === LOYAL BLADE VISUAL ===

## Tween for loyal glow pulsing animation
var loyal_pulse_tween: Tween = null

## Apply ethereal glow to the blood-bound blade — this blade is SPECIAL
## Uses preloaded scene — zero runtime construction, GPU-rendered
## The loyal blade pulses with life — it's connected to the fox
func _apply_loyal_visual() -> void:
	if loyal_glow != null:
		return  # Already applied
	
	# Instantiate pre-authored loyal glow from scene
	loyal_glow = LOYAL_GLOW_SCENE.instantiate()
	add_child(loyal_glow)
	
	# Start pulsing animation — the blade breathes with the fox
	_start_loyal_pulse()
	
	# Visible cool tint — player should SEE this blade is different
	if spinning_sprite:
		spinning_sprite.modulate = Color(0.8, 0.9, 1.0, 1.0)  # Noticeable cool tint
	if landed_sprite:
		landed_sprite.modulate = Color(0.8, 0.9, 1.0, 1.0)

## Pulsing glow — the loyal blade is alive, connected to its master
func _start_loyal_pulse() -> void:
	if loyal_glow == null:
		return
	
	if loyal_pulse_tween:
		loyal_pulse_tween.kill()
	
	loyal_pulse_tween = create_tween().set_loops()
	## Doctrine-compliant glow: 0.4-0.6 energy range (was 0.5-0.9 — flashbang territory)
	loyal_pulse_tween.tween_property(loyal_glow, "energy", 0.55, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loyal_pulse_tween.tween_property(loyal_glow, "energy", 0.35, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Remove loyal visual when blade is no longer loyal (edge case)
func _remove_loyal_visual() -> void:
	if loyal_pulse_tween:
		loyal_pulse_tween.kill()
		loyal_pulse_tween = null
	if loyal_glow != null:
		loyal_glow.queue_free()
		loyal_glow = null
	# Reset sprite tints to default
	if spinning_sprite:
		spinning_sprite.modulate = Color.WHITE
	if landed_sprite:
		landed_sprite.modulate = Color.WHITE


## === SATISFACTION FEEDBACK FUNCTIONS ===
## These create the "juice" that makes blade combat feel satisfying.
## All visuals use Godot-native primitives and preloaded GPU particle scenes.

## Ricochet: Sparks fly, metallic ping, world acknowledges impact
func _spawn_ricochet_feedback() -> void:
	# Metallic ricochet sound
	AudioManager.play_sound("blade_ricochet", 12.0)
	
	# Spawn animated spark effect (AnimatedSprite2D with 11-frame animation)
	# Spawn 2-3 at random rotations for visual variety
	for i in range(randi_range(2, 3)):
		var sparks = RICOCHET_SPARKS_SCENE.instantiate() as AnimatedSprite2D
		sparks.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		sparks.rotation = randf() * TAU  # Random rotation for variety
		sparks.scale = Vector2.ONE * randf_range(0.3, 0.6)  # Slight size variation
		get_tree().current_scene.add_child(sparks)
		
		# Auto-cleanup when animation finishes
		sparks.animation_finished.connect(sparks.queue_free)
	
	# Brief sprite flash — blade glints on impact
	_flash_sprite()

## Landing: Dust puff, soft thud, blade embeds with weight
func _spawn_landing_feedback() -> void:
	# Soft thud sound
	AudioManager.play_sound("blade_land", 8.0)
	
	# Spawn dust puff at blade position
	var dust = DUST_PUFF_SCENE.instantiate()
	dust.global_position = global_position + Vector2(0, 4)  # Slightly below blade
	dust.emitting = true
	get_tree().current_scene.add_child(dust)
	
	# Auto-cleanup
	get_tree().create_timer(0.5).timeout.connect(dust.queue_free)

## Pickup: Flash white, shrink to nothing, satisfying "got it" feel
func _flash_and_shrink() -> void:
	# Flash to white
	var active_sprite = _get_active_sprite()
	var original_modulate = active_sprite.modulate
	active_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)  # Bright flash
	
	# Shrink and fade simultaneously
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(active_sprite, "modulate", Color(1.5, 1.5, 1.5, 0.0), 0.12)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12).set_ease(Tween.EASE_IN)
	
	# Queue free after animation
	tween.chain().tween_callback(queue_free)

## Loss: Blade rusts, sad ting, flakes drift away
func _rust_and_fade() -> void:
	# Sad hollow sound — the blade is dying
	AudioManager.play_sound("blade_lost", 10.0)
	
	# Spawn rust flakes — they linger, a ghost of what was
	var rust = RUST_FLAKES_SCENE.instantiate()
	rust.global_position = global_position
	rust.emitting = true
	get_tree().current_scene.add_child(rust)
	get_tree().create_timer(1.2).timeout.connect(rust.queue_free)  # Longer linger
	
	# Blade turns rust-brown and fades — let the loss BREATHE
	var active_sprite = _get_active_sprite()
	var tween = create_tween()
	
	# First: a brief shudder — the blade tries to resist
	tween.tween_property(self, "rotation", rotation + 0.1, 0.08)
	tween.tween_property(self, "rotation", rotation - 0.1, 0.08)
	tween.tween_property(self, "rotation", rotation, 0.06)
	
	# Then: slow, mournful fade and shrink
	tween.set_parallel(true)
	tween.tween_property(active_sprite, "modulate", Color(0.5, 0.3, 0.2, 0.0), 0.6).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", scale * 0.2, 0.6).set_ease(Tween.EASE_IN_OUT)
	
	# Disable glow during fade
	if grounded_light:
		grounded_light.visible = false
	
	# Queue free after animation
	tween.chain().tween_callback(queue_free)

## Steam burst: Visual feedback when flame enters water
func _spawn_steam_burst() -> void:
	var steam = STEAM_BURST_SCENE.instantiate()
	steam.global_position = global_position
	steam.emitting = true
	get_tree().current_scene.add_child(steam)
	
	# Auto-cleanup
	get_tree().create_timer(0.6).timeout.connect(steam.queue_free)

## Flash sprite: Quick white flash for impact moments
func _flash_sprite() -> void:
	var active_sprite = _get_active_sprite()
	var original_modulate = active_sprite.modulate
	
	# Flash to bright white
	active_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	
	# Return to original
	var tween = create_tween()
	tween.tween_property(active_sprite, "modulate", original_modulate, 0.08)
