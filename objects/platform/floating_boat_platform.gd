extends AnimatableBody2D
class_name FloatingBoatPlatform

## Floating platform that glides left-right on water surface, stays static on ground
## Designed for boss fight mechanics with dynamic water level changes

## === HORIZONTAL MOVEMENT ===
@export_group("Horizontal Movement")
@export var glide_speed: float = 60.0  ## Speed when gliding on water
@export var glide_distance: float = 150.0  ## Distance before changing direction
@export var glide_acceleration: float = 100.0  ## Smooth acceleration/deceleration
@export var glide_pause_time: float = 1.0  ## Pause duration when changing direction

## === BUOYANCY PHYSICS ===
@export_group("Buoyancy Physics")
@export var buoyancy_strength: float = 120.0  ## Spring force strength (higher = faster rise)
@export var float_damping: float = 0.85  ## Velocity damping for stability (0.5-0.95)
@export var wave_follow_strength: float = 0.25  ## Wave motion influence (0.0-0.5)
@export var float_height_offset: float = -8.0  ## Height above water surface (negative = higher)
@export var underwater_force_multiplier: float = 2.0  ## Extra force when deep underwater

## === SETTLEMENT DETECTION ===
@export_group("Settlement Detection")
@export var settlement_threshold: float = 10.0  ## Max velocity_y to be "settled"
@export var settlement_time: float = 0.5  ## Time stable before gliding starts
@export var surface_distance_threshold: float = 5.0  ## Max distance from surface to be "at surface"
@export var wave_following_distance: float = 20.0  ## Distance from surface to enable wave following

## === PHYSICS ===
@export_group("Physics")
@export var gravity: float = 980.0  ## Gravity when in air
@export var max_fall_speed: float = 500.0  ## Terminal velocity
@export var ground_check_distance: float = 2.0  ## Ground raycast length

@onready var water_detector: Area2D = $WaterDetector
@onready var ground_ray: RayCast2D = $GroundRayCast
@onready var glide_timer: Timer = $GlideTimer

## Internal state
var is_floating: bool = false
var current_water: water = null
var is_settled: bool = false
var settlement_timer: float = 0.0
var velocity_x: float = 0.0
var velocity_y: float = 0.0
var glide_direction: int = 1
var start_glide_position_x: float = 0.0
var is_gliding: bool = false

func _ready() -> void:
	sync_to_physics = false
	
	if water_detector:
		water_detector.area_entered.connect(_on_water_entered)
		water_detector.area_exited.connect(_on_water_exited)
	else:
		push_error("[FloatingBoatPlatform] WaterDetector node not found!")
	
	if glide_timer:
		glide_timer.timeout.connect(_on_glide_timer_timeout)
	
	_check_ground_status()

func _physics_process(delta: float) -> void:
	_check_ground_status()
	
	var should_float = current_water != null and not _is_on_solid_ground()
	
	if should_float != is_floating:
		is_floating = should_float
		if should_float:
			_start_floating()
		else:
			_land_on_ground()
	
	# Apply appropriate physics
	if is_floating and current_water:
		_update_buoyancy(delta)
		_check_settlement(delta)
		if is_settled:
			_update_gliding(delta)
	elif not _is_on_solid_ground():
		_apply_gravity(delta)
		if abs(velocity_x) > 0.1:
			velocity_x = move_toward(velocity_x, 0.0, glide_acceleration * 0.5 * delta)
	else:
		velocity_x = 0.0
		velocity_y = 0.0
		is_gliding = false
		if glide_timer and not glide_timer.is_stopped():
			glide_timer.stop()
	
	# Apply movement with collision
	var motion = Vector2(velocity_x * delta, velocity_y * delta)
	var collision = move_and_collide(motion)
	
	if collision and collision.get_normal().y < -0.5:
		velocity_y = 0.0
		if not is_floating:
			velocity_x = 0.0

func _is_on_solid_ground() -> bool:
	if current_water != null:
		return false
	
	if not ground_ray or not ground_ray.is_colliding():
		return false
	
	var collider = ground_ray.get_collider()
	return collider and collider.is_in_group("ground")

func _check_ground_status() -> void:
	if ground_ray:
		ground_ray.force_raycast_update()

func _check_settlement(delta: float) -> void:
	if not current_water:
		return
	
	var water_surface_y = current_water.get_water_surface_global_y()
	var target_y = water_surface_y + float_height_offset
	var distance_to_surface = abs(global_position.y - target_y)
	
	var at_surface = distance_to_surface <= surface_distance_threshold
	var stable_velocity = abs(velocity_y) <= settlement_threshold
	
	if at_surface and stable_velocity:
		settlement_timer += delta
		if settlement_timer >= settlement_time and not is_settled:
			is_settled = true
			_start_gliding()
	else:
		settlement_timer = 0.0
		is_settled = false
		is_gliding = false

func _apply_gravity(delta: float) -> void:
	velocity_y += gravity * delta
	velocity_y = minf(velocity_y, max_fall_speed)

func _update_buoyancy(delta: float) -> void:
	if not current_water:
		return
	
	var water_surface_y = current_water.get_water_surface_global_y()
	var target_y = water_surface_y + float_height_offset
	
	if water_surface_y >= global_position.y:
		pass
	else:
		velocity_y = 0.0
		return
	
	var raw_displacement = target_y - global_position.y
	
	# Only follow waves when near surface
	var wave_offset = 0.0
	if abs(raw_displacement) < wave_following_distance:
		wave_offset = _sample_water_waves()
		target_y += wave_offset * wave_follow_strength
	
	var displacement = target_y - global_position.y
	
	# Stronger force when deep underwater
	var buoyancy_multiplier = 1.0
	if displacement < -10.0:
		buoyancy_multiplier = underwater_force_multiplier
	
	var buoyant_acceleration = displacement * buoyancy_strength * buoyancy_multiplier
	
	# Less damping when far from surface
	var damping = float_damping if abs(displacement) < 10.0 else 0.95
	velocity_y += buoyant_acceleration * delta
	velocity_y *= damping
	
	velocity_y = clampf(velocity_y, -300.0, 300.0)

func _sample_water_waves() -> float:
	## Sample water surface at boat position for wave following
	## Returns average displacement from flat surface
	if not current_water or not current_water.segment_data:
		return 0.0
	
	var local_x = current_water.to_local(global_position).x
	var segment_width = current_water.water_size.x / (current_water.segment_count - 1)
	var index = int(clamp(local_x / segment_width, 0, current_water.segment_count - 1))
	
	# Average nearby segments for smoother following
	var total = 0.0
	var count = 0
	for i in range(max(0, index - 2), min(current_water.segment_count, index + 3)):
		total += current_water.segment_data[i]["height"] - current_water.surface_pos_y
		count += 1
	
	return total / count if count > 0 else 0.0

func _update_gliding(delta: float) -> void:
	if not is_gliding:
		if abs(velocity_x) > 0.1:
			velocity_x = move_toward(velocity_x, 0.0, glide_acceleration * 2.0 * delta)
		else:
			velocity_x = 0.0
		return
	
	var target_velocity = glide_speed * glide_direction
	velocity_x = move_toward(velocity_x, target_velocity, glide_acceleration * delta)
	
	var distance_traveled = abs(global_position.x - start_glide_position_x)
	if distance_traveled >= glide_distance:
		_pause_gliding()

func _start_floating() -> void:
	is_floating = true
	is_settled = false
	settlement_timer = 0.0
	is_gliding = false

func _start_gliding() -> void:
	start_glide_position_x = global_position.x
	is_gliding = true
	glide_direction = 1

func _land_on_ground() -> void:
	is_floating = false
	is_settled = false
	settlement_timer = 0.0
	velocity_x = 0.0
	velocity_y = 0.0
	is_gliding = false
	if glide_timer and not glide_timer.is_stopped():
		glide_timer.stop()

func _pause_gliding() -> void:
	is_gliding = false
	glide_direction *= -1
	start_glide_position_x = global_position.x
	glide_timer.start(glide_pause_time)

func _on_glide_timer_timeout() -> void:
	if is_floating:
		is_gliding = true

func _on_water_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is water or (parent and parent.is_in_group("water")):
		current_water = parent

func _on_water_exited(area: Area2D) -> void:
	var parent = area.get_parent()
	if (parent is water or (parent and parent.is_in_group("water"))) and parent == current_water:
		current_water = null
