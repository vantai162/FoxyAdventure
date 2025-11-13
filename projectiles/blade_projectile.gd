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

# Internal state
var distance_traveled: float = 0.0
var thrower: Player = null
var ground_timer: Timer = null
var throw_direction: int = 1
var hit_area: Area2D = null
var trail_spawn_timer: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 + 2
	gravity_space_override = Area2D.SPACE_OVERRIDE_DISABLED
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	ground_timer = Timer.new()
	add_child(ground_timer)
	ground_timer.wait_time = pickup_delay_seconds
	ground_timer.one_shot = true
	ground_timer.timeout.connect(_on_ground_timer_timeout)
	
	hit_area = get_node_or_null("HitArea2D")

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
		State.GROUNDED:
			return
	
	if trail_enabled:
		_update_trail(delta)

func _update_flying(delta: float) -> void:
	distance_traveled += velocity.length() * delta
	
	if distance_traveled >= max_flight_distance:
		_transition_to_arc_down()
		return
	
	position += velocity * delta
	rotation += rotation_speed_flying * delta

func _update_bounced(delta: float) -> void:
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
	rotation += rotation_speed_bouncing * delta

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

func _transition_to_arc_down() -> void:
	current_state = State.BOUNCED
	velocity.x *= speed_after_max_distance
	velocity.y = 0

func _transition_to_ricochet(_impact_normal: Vector2) -> void:
	current_state = State.BOUNCED
	
	var distance_ratio = distance_traveled / max_flight_distance
	var backward_direction = Vector2(-throw_direction, first_bounce_upward_angle).normalized()
	var bounce_speed = initial_throw_speed * bounce_energy_retention * (close_bounce_speed_multiplier + distance_ratio * far_bounce_speed_multiplier)
	
	velocity = backward_direction * bounce_speed
	velocity.y -= first_bounce_upward_force

func _transition_to_grounded() -> void:
	current_state = State.GROUNDED
	velocity = Vector2.ZERO
	rotation = 0
	collision_mask = 2
	ground_timer.start()
	
	if hit_area:
		hit_area.set_deferred("monitoring", false)

func _on_body_entered(body: Node) -> void:
	if body == thrower:
		_pickup_by_player()
		return
	
	if current_state == State.FLYING:
		if body is EnemyCharacter and body.has_method("take_damage"):
			body.take_damage(damage)
		
		if body is TileMapLayer or body is StaticBody2D or body is CharacterBody2D:
			_transition_to_ricochet(Vector2.ZERO)
	
	elif current_state == State.BOUNCED:
		if body is EnemyCharacter and body.has_method("take_damage"):
			body.take_damage(damage)

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() == thrower:
		_pickup_by_player()
		return
	
	if area.owner is EnemyCharacter and area.owner.has_method("take_damage"):
		area.owner.take_damage(damage)
		if current_state == State.FLYING:
			_transition_to_ricochet(Vector2.ZERO)

func _pickup_by_player() -> void:
	if thrower and thrower.has_method("return_blade"):
		thrower.return_blade()
	queue_free()

func _on_ground_timer_timeout() -> void:
	_pickup_by_player()
