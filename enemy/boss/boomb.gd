extends RigidBody2D

@export var speed: float = 350.0
@export var lift_force: float = -200.0 
@export var roll_speed: float = 200.0

@export_group("Water Buoyancy")
@export var buoyancy_force: float = 50.0       ## Spring force when submerged (lower = gentler)
@export var water_drag: float = 3.0            ## Velocity dampening in water
@export var float_offset: float = -10.0        ## Target height above water surface
@export var max_buoyancy_velocity: float = 300.0  ## Cap on upward speed in water
@onready var explode_sound = $ExplodeSound

var roll_dir =1
var direction := 1
var exploded: = false
var current_water: water = null
var is_in_water: bool = false

@onready var sprite = $Sprite
@onready var explosion: AnimatedSprite2D = $Explosion
@onready var flying_hitbox = $DirectionArea          
@onready var explosion_area = $HitArea2D 
@onready var explosion_hitbox = $HitArea2D/CollisionShape2D
@onready var timer = $Timer
@onready var explosion_timer = $Explosion_Timer

func _ready() -> void:
	explosion.visible = false
	explosion_hitbox.set_deferred("disabled", true)
	explosion_area.monitoring = false
	apply_impulse(Vector2(direction*speed,lift_force))
	explosion_timer.start()
	
	# Start checking for water
	set_physics_process(true)
func _physics_process(delta: float) -> void:
	if exploded:
		return
	
	# Detect water presence (used by integrate_forces)
	_detect_water()
	
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if exploded:
		return
	
	# Apply buoyancy in physics step if in water
	if is_in_water and current_water:
		_apply_buoyancy_forces(state)
	
	# Ground rolling behavior
	var vel = linear_velocity
	if abs(vel.y) > 1.0:
		return
	
	vel.x = roll_dir * roll_speed
	linear_velocity = vel

func _detect_water() -> void:
	## Check if bomb is in water using global position
	var bomb_center_y = global_position.y
	var found_water: water = null
	
	for water_node in get_tree().get_nodes_in_group("water"):
		if not water_node is water:
			continue
		
		var water_obj = water_node as water
		var water_surface_y = water_obj.get_water_surface_global_y()
		var water_bottom_y = water_obj.global_position.y + water_obj.water_size.y
		
		# Check horizontal bounds
		var bomb_local_x = water_obj.to_local(global_position).x
		if bomb_local_x >= 0 and bomb_local_x <= water_obj.water_size.x:
			# Check if submerged (below surface)
			if bomb_center_y >= water_surface_y and bomb_center_y <= water_bottom_y:
				found_water = water_obj
				break
	
	var was_in_water = is_in_water
	current_water = found_water
	is_in_water = found_water != null

func _apply_buoyancy_forces(state: PhysicsDirectBodyState2D) -> void:
	## Apply buoyancy physics directly in integrate_forces for proper RigidBody2D handling
	if not current_water:
		return
	
	# Get water surface at bomb position
	var water_surface_y = current_water.get_water_surface_global_y()
	var target_y = water_surface_y + float_offset
	
	# Calculate submersion (positive = underwater)
	var displacement = global_position.y - target_y
	
	# Only apply buoyancy when submerged
	if displacement > 0:
		# Spring force proportional to depth (like boat)
		var spring_force = -displacement * buoyancy_force
		
		# Damping force to prevent oscillation
		var damping_force = -state.linear_velocity.y * water_drag
		
		# Combine forces and apply to velocity
		var total_force = spring_force + damping_force
		var delta = state.step
		state.linear_velocity.y += total_force * delta
		
		# Hard cap upward velocity to prevent space launch
		state.linear_velocity.y = clamp(state.linear_velocity.y, -max_buoyancy_velocity, max_buoyancy_velocity)
		
		# Apply horizontal drag in water
		state.linear_velocity.x *= 0.98  # 2% horizontal drag per frame

func _apply_buoyancy(delta: float) -> void:
	## Deprecated - now using _apply_buoyancy_forces in integrate_forces
	pass
func explode():
	exploded = true
	linear_velocity = Vector2.ZERO
	gravity_scale = 0
	apply_impulse(Vector2.ZERO)
	sprite.visible=false
	explosion.visible = true
	explosion.play("default")
	explosion_hitbox.disabled = false
	timer.start()
	explode_sound.play()
	


func set_speed(_speed:float):
	speed= _speed
func set_lift_force(_lift_force:float):
	lift_force=_lift_force




func _on_timer_timeout() -> void:
	queue_free()
	explosion_area.set_collision_mask_value(5, false)
	flying_hitbox.set_collision_mask_value(4,false)


func _on_direction_area_body_entered(body: Node2D) -> void:
	explode()
	explosion_hitbox.set_deferred("disabled", false)
	explosion_area.monitoring = true


func _on_explosion_timer_timeout() -> void:
	explode()
	explosion_hitbox.set_deferred("disabled", false)
	explosion_area.monitoring = true


func _on_direction_area_area_entered(area: Area2D) -> void:
	explosion_timer.start()
	direction*=-1
	flying_hitbox.set_collision_mask_value(4,true)
	explosion_area.set_collision_mask_value(5, true)
	
