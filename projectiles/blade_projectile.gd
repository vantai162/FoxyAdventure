extends Area2D
class_name BladeProjectile

enum State { FLYING, BOUNCED, GROUNDED }

var current_state: State = State.FLYING
var velocity: Vector2 = Vector2.ZERO
var damage: int = 1

# Flight parameters
@export var throw_speed: float = 400.0
@export var max_range: float = 300.0

# Ricochet physics
@export var bounce_speed_retention: float = 0.6  # How much speed is kept after bounce (0.6 = 60%)
@export var bounce_upward_force: float = 300.0  # Vertical boost when bouncing (higher = more upward arc)
@export var bounce_return_influence: float = 0.7  # How much distance affects return trajectory (0-1)

# Flight behavior
@export var spin_speed_flying: float = 0.1  # Rotation speed while flying straight
@export var spin_speed_bounced: float = 0.15  # Rotation speed after bounce

# Grounded behavior
@export var ground_auto_return_time: float = 6.5

var distance_traveled: float = 0.0
var thrower: Player = null
var ground_timer: Timer = null
var throw_direction: int = 1
var hit_area: Area2D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 + 2  # Environment (1) + Player body (2)
	
	# Use Area2D's built-in gravity (no need to define our own)
	gravity_space_override = Area2D.SPACE_OVERRIDE_DISABLED
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	ground_timer = Timer.new()
	add_child(ground_timer)
	ground_timer.wait_time = ground_auto_return_time
	ground_timer.one_shot = true
	ground_timer.timeout.connect(_on_ground_timer_timeout)
	
	# Get reference to HitArea2D child for damage control
	hit_area = get_node_or_null("HitArea2D")

func launch(direction: int, from_player: Player) -> void:
	thrower = from_player
	throw_direction = direction
	velocity = Vector2(direction * throw_speed, 0)
	
	# Proper orientation based on throw direction
	if direction > 0:
		rotation_degrees = 0
		scale.x = 1
	else:
		rotation_degrees = 0
		scale.x = -1

func _physics_process(delta: float) -> void:
	match current_state:
		State.FLYING:
			_update_flying(delta)
		State.BOUNCED:
			_update_bounced(delta)
		State.GROUNDED:
			pass

func _update_flying(delta: float) -> void:
	var motion = velocity * delta
	distance_traveled += motion.length()
	
	# Max range reached - arc down gracefully (not a ricochet)
	if distance_traveled >= max_range:
		_transition_to_arc_down()
		return
	
	position += motion
	rotation += velocity.x * delta * spin_speed_flying

func _update_bounced(delta: float) -> void:
	# Use project gravity from ProjectSettings
	var project_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	velocity.y += project_gravity * delta
	position += velocity * delta
	rotation += velocity.x * delta * spin_speed_bounced
	
	if velocity.y > 0 and _check_ground_below():
		_transition_to_grounded()

func _on_body_entered(body: Node) -> void:
	# Check if player catches the blade
	if body == thrower:
		_pickup_by_player()
		return
	
	if current_state == State.FLYING:
		# Damage enemies on hit
		if body is EnemyCharacter:
			if body.has_method("take_damage"):
				body.take_damage(damage)
		
		# Collision ricochet - bounce off walls, ground, or enemies
		if body is TileMap or body is StaticBody2D or body is CharacterBody2D:
			var impact_normal = _calculate_impact_normal(body)
			_transition_to_ricochet(impact_normal)

func _on_area_entered(area: Area2D) -> void:
	# Also check area collision in case player uses hurt area
	if area.get_parent() == thrower:
		_pickup_by_player()
	elif current_state == State.FLYING:
		# Hit enemy hurt areas
		if area.owner is EnemyCharacter:
			var impact_direction = (global_position - area.global_position).normalized()
			_transition_to_ricochet(impact_direction)

func _transition_to_arc_down() -> void:
	"""Max range reached - blade arcs down naturally without bouncing back"""
	current_state = State.BOUNCED
	# Keep forward momentum but reduce it and start falling
	velocity.x *= 0.3
	velocity.y = 0  # Will be pulled down by gravity in _update_bounced

func _transition_to_ricochet(impact_normal: Vector2) -> void:
	"""Hit something - bounce back toward player with distance compensation"""
	current_state = State.BOUNCED
	
	# Calculate how far we traveled (0.0 = just thrown, 1.0 = max range)
	var distance_ratio = distance_traveled / max_range
	
	# Base bounce direction away from impact
	var bounce_direction = velocity.bounce(impact_normal).normalized()
	
	# Stronger backward force if traveled far (helps land closer to player)
	var return_strength = distance_ratio * bounce_return_influence
	if thrower:
		var to_player = (thrower.global_position - global_position).normalized()
		bounce_direction = (bounce_direction * (1.0 - return_strength) + to_player * return_strength).normalized()
	
	# Ensure upward component for arc
	bounce_direction.y = min(bounce_direction.y, -0.3)
	
	# Apply velocity with distance-based force
	var bounce_speed = throw_speed * bounce_speed_retention * (0.7 + distance_ratio * 0.6)
	velocity = bounce_direction * bounce_speed
	velocity.y -= bounce_upward_force

func _transition_to_grounded() -> void:
	current_state = State.GROUNDED
	velocity = Vector2.ZERO
	rotation = 0
	ground_timer.start()
	
	# Only detect player body when grounded
	collision_mask = 2
	
	# Disable HitArea2D so blade doesn't damage enemies while on ground
	if hit_area:
		hit_area.set_deferred("monitoring", false)

func _check_ground_below() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, 10)
	)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func _calculate_impact_normal(body: Node) -> Vector2:
	if body is TileMap or body is StaticBody2D:
		var to_blade = (global_position - body.global_position).normalized()
		return to_blade
	return Vector2.UP

func _pickup_by_player() -> void:
	if thrower and thrower.has_method("return_blade"):
		thrower.return_blade()
	queue_free()

func _on_ground_timer_timeout() -> void:
	_pickup_by_player()
