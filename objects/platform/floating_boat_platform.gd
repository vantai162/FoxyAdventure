extends AnimatableBody2D
class_name FloatingBoatPlatform

## Floating platform that bobs gently on water surface
## Simple behavior: stays on water, oscillates randomly to feel alive
## Player can ride on top

## === MOVEMENT ===
@export_group("Horizontal Drift")
@export var enable_drift: bool = true  ## Boat drifts left/right gently
@export var drift_speed: float = 20.0  ## Max horizontal drift speed
@export var drift_change_interval: float = 2.0  ## How often drift changes direction (seconds)
@export var drift_randomness: float = 0.5  ## 0 = predictable, 1 = very random

## === BOBBING (Vertical Oscillation) ===
@export_group("Bobbing Motion")
@export var bob_enabled: bool = true  ## Gentle up/down bobbing
@export var bob_amplitude: float = 4.0  ## How far up/down (pixels)
@export var bob_speed: float = 1.5  ## How fast the bob cycle
@export var bob_randomness: float = 0.3  ## Variation in bobbing

## === BUOYANCY ===
@export_group("Water Physics")
@export var buoyancy_strength: float = 50.0  ## Spring force to water surface
@export var float_damping: float = 5.0  ## Prevents endless bouncing
@export var float_height_offset: float = -8.0  ## Target height above water surface
@export var rider_weight_sink: float = 3.0  ## Extra sink depth when player is on boat (pixels)
@export var rider_landing_impulse: float = 2.5  ## Downward push when player lands on boat

## === GENERAL ===
@export_group("General")
@export var gravity: float = 980.0  ## Gravity when not in water
@export var max_fall_speed: float = 500.0

@onready var ground_ray: RayCast2D = $GroundRayCast if has_node("GroundRayCast") else null

## Internal state
var is_floating: bool = false
var current_water: water = null
var velocity_x: float = 0.0
var velocity_y: float = 0.0

## Rider detection
var _rider_on_boat: bool = false
var _rider_just_landed: bool = false
var _rider_check_area: Area2D = null

## Randomized motion state
var _bob_phase: float = 0.0
var _bob_speed_actual: float = 1.5
var _drift_direction: int = 1
var _drift_timer: float = 0.0
var _drift_speed_actual: float = 0.0

func _ready() -> void:
	sync_to_physics = false
	
	# Randomize initial state so multiple boats don't sync
	_bob_phase = randf() * TAU
	_bob_speed_actual = bob_speed * randf_range(0.8, 1.2)
	_drift_direction = 1 if randf() > 0.5 else -1
	_drift_timer = randf() * drift_change_interval
	_drift_speed_actual = drift_speed * randf_range(0.5, 1.0)
	
	# Create rider detection area
	_setup_rider_detection()

func _physics_process(delta: float) -> void:
	_detect_water()
	
	var was_floating = is_floating
	is_floating = current_water != null and not _is_on_solid_ground()
	
	if is_floating and current_water:
		_update_buoyancy(delta)
		if bob_enabled:
			_update_bobbing(delta)
		if enable_drift:
			_update_drift(delta)
	elif not _is_on_solid_ground():
		# Falling through air
		velocity_y += gravity * delta
		velocity_y = minf(velocity_y, max_fall_speed)
	else:
		# On ground - no movement
		velocity_x = 0.0
		velocity_y = 0.0
	
	# Apply movement
	var motion = Vector2(velocity_x * delta, velocity_y * delta)
	move_and_collide(motion)

func _detect_water() -> void:
	## Find water at boat position
	var boat_y = global_position.y + 4
	var found_water: water = null
	
	for water_node in get_tree().get_nodes_in_group("water"):
		if not water_node is water:
			continue
		
		var w = water_node as water
		var surface_y = w.get_water_surface_global_y()
		var bottom_y = w.global_position.y + w.water_size.y
		var local_x = w.to_local(global_position).x
		
		# Check horizontal bounds
		if local_x >= 0 and local_x <= w.water_size.x:
			# Check if we're near/in water
			if boat_y >= surface_y - 30 and boat_y <= bottom_y:
				found_water = w
				break
	
	current_water = found_water

func _is_on_solid_ground() -> bool:
	if current_water != null:
		return false
	if ground_ray and ground_ray.is_colliding():
		var collider = ground_ray.get_collider()
		return collider and collider.is_in_group("ground")
	return false

func _update_buoyancy(delta: float) -> void:
	if not current_water:
		return
	
	var surface_y = current_water.get_water_surface_global_y()
	
	# Calculate target depth - sink deeper when carrying a rider
	var effective_offset = float_height_offset
	if _rider_on_boat:
		effective_offset += rider_weight_sink  # Sink deeper with rider
	
	var target_y = surface_y + effective_offset
	var displacement = global_position.y - target_y
	
	# Spring force
	var spring_force = -displacement * buoyancy_strength
	
	# Damping
	var damping = -velocity_y * float_damping
	
	# Landing impulse - push boat down when player first lands
	if _rider_just_landed:
		velocity_y += rider_landing_impulse * 50.0  # Immediate downward push
		_rider_just_landed = false
	
	velocity_y += (spring_force + damping) * delta
	velocity_y = clamp(velocity_y, -max_fall_speed, max_fall_speed)

func _update_bobbing(delta: float) -> void:
	## Simple sine-wave bobbing
	_bob_phase += _bob_speed_actual * delta
	if _bob_phase > TAU:
		_bob_phase -= TAU
		# Add randomness each cycle
		if bob_randomness > 0:
			_bob_speed_actual = bob_speed * randf_range(1.0 - bob_randomness, 1.0 + bob_randomness)
	
	# Apply bobbing as additional velocity push
	var bob_offset = sin(_bob_phase) * bob_amplitude * delta * 10.0
	velocity_y += bob_offset

func _update_drift(delta: float) -> void:
	## Random horizontal drift
	_drift_timer -= delta
	
	if _drift_timer <= 0:
		# Change drift
		_drift_timer = drift_change_interval * randf_range(0.5, 1.5)
		
		if randf() < drift_randomness:
			_drift_direction *= -1
		
		_drift_speed_actual = drift_speed * randf_range(0.3, 1.0)
	
	velocity_x = move_toward(velocity_x, _drift_speed_actual * _drift_direction, drift_speed * delta * 2.0)

## ============================================================================
## RIDER DETECTION
## Detects when player lands on boat for weight-based buoyancy
## ============================================================================

func _setup_rider_detection() -> void:
	## Create an Area2D above the boat to detect when player lands
	_rider_check_area = Area2D.new()
	_rider_check_area.name = "RiderDetector"
	_rider_check_area.collision_layer = 0
	_rider_check_area.collision_mask = 2  # Player layer
	_rider_check_area.monitoring = true
	_rider_check_area.monitorable = false
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(56, 20)  # Slightly wider than boat, thin height
	shape.shape = rect
	shape.position = Vector2(0, -12)  # Above boat surface
	
	_rider_check_area.add_child(shape)
	add_child(_rider_check_area)
	
	_rider_check_area.body_entered.connect(_on_rider_entered)
	_rider_check_area.body_exited.connect(_on_rider_exited)

func _on_rider_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var was_on_boat = _rider_on_boat
		_rider_on_boat = true
		
		# Check if player just landed (falling onto boat)
		if not was_on_boat and body.velocity.y > 50.0:
			_rider_just_landed = true
			
			# Also create a splash in water when player lands on boat
			if current_water:
				var landing_splash = body.velocity.y * 0.15
				current_water.splash(global_position, landing_splash)

func _on_rider_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_rider_on_boat = false
		
		# Create small splash when player jumps off
		if current_water and is_floating:
			current_water.splash(global_position, -1.5)
