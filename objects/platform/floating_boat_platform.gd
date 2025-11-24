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
@export var buoyancy_strength: float = 50.0  ## Spring force strength (higher = faster rise)
@export var float_damping: float = 5.0  ## Velocity damping for stability (higher = less bouncy)
@export var wave_follow_strength: float = 0.5  ## How much the boat tilts/moves with waves (0.15 was too low for whirlpools)
@export var float_height_offset: float = -8.0  ## Target height relative to water surface (negative = above)

@export_group("Advanced Physics")
@export var underwater_force_multiplier: float = 1.5  ## Extra force when deep underwater
@export var settlement_threshold: float = 15.0  ## Max velocity_y to be "settled" (increased for whirlpool oscillations)
@export var settlement_time: float = 0.5  ## Time stable before gliding starts
@export var surface_distance_threshold: float = 25.0  ## Max distance from surface to be "at surface" (increased for whirlpool waves)
@export var wave_following_distance: float = 20.0  ## Distance from surface to enable wave following

## === PHYSICS ===
@export_group("General Physics")
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
var external_force_x: float = 0.0
var external_force_y: float = 0.0
var glide_direction: int = 1
var start_glide_position_x: float = 0.0
var is_gliding: bool = false

func _ready() -> void:
	sync_to_physics = false
	
	if glide_timer:
		glide_timer.timeout.connect(_on_glide_timer_timeout)
	
	_check_ground_status()

func _physics_process(delta: float) -> void:
	velocity_x += external_force_x
	velocity_y += external_force_y
	external_force_x = 0.0
	external_force_y = 0.0
	
	_check_ground_status()
	_detect_water_by_position()  # New global detection method
	
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

func _detect_water_by_position() -> void:
	## Global water detection using position-based checking
	## Works with any water node in the "water" group - like foam on water
	var boat_bottom_y = global_position.y + 4  # Bottom edge of boat
	var detection_range = 20.0  # Detect water within 20px above/below boat
	var found_water: water = null
	
	# Check all water bodies in the scene
	for water_node in get_tree().get_nodes_in_group("water"):
		if not water_node is water:
			continue
		
		var water_obj = water_node as water
		var water_surface_global_y = water_obj.get_water_surface_global_y()
		var water_bottom_global_y = water_obj.global_position.y + water_obj.water_size.y
		
		# Check if boat overlaps with water volume (horizontally and vertically)
		var boat_local_x = water_obj.to_local(global_position).x
		if boat_local_x >= 0 and boat_local_x <= water_obj.water_size.x:
			# Boat is within water's horizontal bounds
			# Check if boat is near water surface (above or below)
			var distance_to_surface = boat_bottom_y - water_surface_global_y
			if distance_to_surface >= -detection_range and boat_bottom_y <= water_bottom_global_y:
				# Boat is near surface or inside water
				found_water = water_obj
				break
	
	var prev_water = current_water
	current_water = found_water

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
		# Not in water: apply gravity
		velocity_y += gravity * delta
		velocity_y = clamp(velocity_y, -max_fall_speed, max_fall_speed)
		return

	# 1. Get baseline water surface (flat)
	var flat_surface_y = current_water.get_water_surface_global_y()
	
	# 2. Get exact water height (waves/whirlpools)
	var exact_surface_y = flat_surface_y
	if current_water.has_method("get_water_height_at_global_x"):
		exact_surface_y = current_water.get_water_height_at_global_x(global_position.x)
	
	# 3. Calculate target height with wave influence
	# wave_follow_strength 0.0 = treat water as flat
	# wave_follow_strength 1.0 = follow every ripple exactly
	var wave_displacement = exact_surface_y - flat_surface_y
	var effective_surface_y = flat_surface_y + (wave_displacement * wave_follow_strength)
	
	var target_y = effective_surface_y + float_height_offset

	# 4. Calculate displacement (positive = submerged)
	var displacement = global_position.y - target_y

	# If boat is well above the surface (e.g. jumped out), behave like normal falling body
	# Use wave_following_distance as the "capture radius" of the water
	if displacement < -wave_following_distance:
		velocity_y += gravity * delta
		velocity_y = clamp(velocity_y, -max_fall_speed, max_fall_speed)
		return

	# 5. Apply Spring Force (Buoyancy)
	# Pulls/pushes toward target_y
	var spring_force = -displacement * buoyancy_strength
	
	# When underwater (below target), apply extra buoyancy boost to pop up
	if displacement > 0.0:
		spring_force *= underwater_force_multiplier

	# 6. Apply Damping (Stability)
	# Stronger damping when near target to prevent endless oscillation
	var damping_factor = float_damping
	if abs(displacement) < 5.0:
		damping_factor *= 2.0
	
	var damping_force = -velocity_y * damping_factor

	# 7. Integrate Forces
	velocity_y += (spring_force + damping_force + gravity) * delta
	velocity_y = clamp(velocity_y, -max_fall_speed, max_fall_speed)

# _sample_water_waves removed - replaced by current_water.get_water_height_at_global_x()

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
