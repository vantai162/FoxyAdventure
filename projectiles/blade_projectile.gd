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

@export_subgroup("Motion Blur Trail")
@export var trail_enabled: bool = true
@export var trail_texture: Texture2D
@export var trail_spawn_rate: float = 0.05
@export var trail_ghost_fade_time: float = 0.25
@export var trail_minimum_speed: float = 50.0

@export_group("Grounded")
@export var pickup_delay_seconds: float = 6.5
@export var grounded_glow_color: Color = Color(1.5, 1.3, 0.5, 1.0)  ## Highlight color for grounded blade (bright yellow)
@export var glow_blink_speed: float = 4.0  ## Speed of blink effect
@export var glow_off_brightness: float = 1.0  ## Brightness when "off" (normal sprite)
@export var glow_on_brightness: float = 2.5  ## Brightness when "on" (super bright)

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
var trail_spawn_timer: float = 0.0
var glow_time: float = 0.0  # For pulsing glow effect
var bounced_time: float = 0.0  # Time spent in BOUNCED state

@onready var ground_timer: Timer = $GroundTimer
@onready var hit_area: Area2D = $HitArea2D
@onready var spinning_sprite: Sprite2D = $Sprite2D
@onready var landed_sprite: Sprite2D = $Sprite2D2

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Only set if not already configured in editor
	if ground_timer.wait_time == 0:
		ground_timer.wait_time = pickup_delay_seconds
	if not ground_timer.one_shot:
		ground_timer.one_shot = true
	ground_timer.timeout.connect(_on_ground_timer_timeout)
	
	if hit_area.damage == 0:
		hit_area.damage = damage

func launch(direction: int, from_player: Player) -> void:
	thrower = from_player
	throw_direction = direction
	velocity = Vector2(direction * initial_throw_speed, 0)
	scale.x = direction
	current_state = State.FLYING
	trail_spawn_timer = 0

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
		_pickup_by_player()
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
	var speed = velocity.length()
	if speed < trail_minimum_speed:
		return
	
	trail_spawn_timer -= delta
	if trail_spawn_timer <= 0:
		trail_spawn_timer = trail_spawn_rate
		_spawn_trail()

func _spawn_trail() -> void:
	if not trail_texture:
		return
	
	var parent = get_parent()
	if not parent:
		return
	
	var trail = Sprite2D.new()
	trail.texture = trail_texture
	trail.global_position = global_position
	trail.global_rotation = global_rotation
	trail.scale = scale
	trail.modulate = Color(1, 1, 1, 0.6)
	trail.z_index = z_index - 1
	
	parent.add_child(trail)
	
	var tween = trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, trail_ghost_fade_time)
	tween.tween_callback(trail.queue_free)

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
	if not landed_sprite.visible:
		return
	
	# Blink effect with sharp on/off transitions
	glow_time += delta * glow_blink_speed
	var blink_cycle = fmod(glow_time, 1.0)  # 0 to 1 repeating cycle
	
	# Sharp square wave blink (50% on, 50% off)
	var brightness: float
	if blink_cycle < 0.5:
		brightness = glow_on_brightness  # BRIGHT
	else:
		brightness = glow_off_brightness  # Normal
	
	# Apply glow color with blinking brightness
	landed_sprite.modulate = grounded_glow_color * brightness

func _transition_to_arc_down() -> void:
	current_state = State.BOUNCED
	bounced_time = 0.0
	velocity.x *= speed_after_max_distance
	velocity.y = 0

func _transition_to_ricochet(_impact_normal: Vector2) -> void:
	current_state = State.BOUNCED
	bounced_time = 0.0
	
	var distance_ratio = distance_traveled / max_flight_distance
	var backward_direction = Vector2(-throw_direction, first_bounce_upward_angle).normalized()
	var bounce_speed = initial_throw_speed * bounce_energy_retention * (close_bounce_speed_multiplier + distance_ratio * far_bounce_speed_multiplier)
	
	velocity = backward_direction * bounce_speed
	velocity.y -= first_bounce_upward_force

func _transition_to_grounded() -> void:
	current_state = State.GROUNDED
	velocity = Vector2.ZERO
	rotation = 0  # Orient blade upright
	collision_mask = 2  # Only detect player for pickup
	ground_timer.start()
	
	hit_area.monitoring = false
	spinning_sprite.visible = false
	landed_sprite.visible = true
	glow_time = 0.0  # Reset glow animation

func _on_body_entered(body: Node) -> void:
	# Pickup by player
	if body == thrower:
		_pickup_by_player()
		return
	
	# Ricochet off ANY solid body during flight (walls, ground, enemies, shields)
	if current_state == State.FLYING:
		_transition_to_ricochet(Vector2.ZERO)

func _on_area_entered(area: Area2D) -> void:
	# Pickup by player's HurtArea or other areas
	if area.get_parent() == thrower:
		_pickup_by_player()
		return

func _pickup_by_player() -> void:
	if thrower and thrower.has_method("return_blade"):
		thrower.return_blade()
	queue_free()

func _on_ground_timer_timeout() -> void:
	_pickup_by_player()
