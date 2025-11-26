extends Area2D

## King Crab claw projectile - travels horizontally, wraps around screen, returns to boss
## All movement values are set by claw_attack.gd from the King Crab's centralized exports

signal returned_to_owner  ## Emitted when claw reaches the crab after wrapping

# Movement settings - set by claw_attack state before calling setup()
var speed: float = 0.0
var travel_distance: float = 0.0
var return_threshold: float = 0.0
var wrap_offset_ratio: float = 0.0

var is_returning: bool = false
var launch_direction: int = 1
var owner_crab: Node2D = null
var launch_x: float = 0.0
var launch_y: float = 0.0  ## Keep Y constant throughout flight

const MAX_LIFETIME: float = 10.0
var lifetime: float = 0.0


func setup(direction: int, crab: Node2D) -> void:
	## Called by claw_attack state after spawning
	launch_direction = direction if direction != 0 else 1
	owner_crab = crab
	launch_x = global_position.x
	launch_y = global_position.y  ## Store original Y
	is_returning = false
	
	# Standard codebase pattern: scale.x = direction (1=right, -1=left)
	scale.x = launch_direction


func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime > MAX_LIFETIME:
		queue_free()
		return
	
	if not is_returning:
		_do_launch(delta)
	else:
		_do_return(delta)


func _do_launch(delta: float) -> void:
	# Move horizontally
	global_position.x += speed * launch_direction * delta
	
	# Check if traveled far enough
	var traveled = abs(global_position.x - launch_x)
	if traveled >= travel_distance:
		_wrap_and_start_return()


func _wrap_and_start_return() -> void:
	if not owner_crab or not is_instance_valid(owner_crab):
		queue_free()
		return
	
	# Teleport to opposite side of crab (far behind it), keep original Y
	var offset = travel_distance * wrap_offset_ratio * -launch_direction
	global_position.x = owner_crab.global_position.x + offset
	global_position.y = launch_y  ## Keep original launch height
	
	# Calculate return direction (toward crab from new position)
	var return_dir = sign(owner_crab.global_position.x - global_position.x)
	
	# Flip sprite to face return direction
	scale.x = return_dir
	
	is_returning = true


func _do_return(delta: float) -> void:
	if not owner_crab or not is_instance_valid(owner_crab):
		queue_free()
		return
	
	# Move toward crab (direction based on relative position, not launch direction)
	var dir_to_crab = sign(owner_crab.global_position.x - global_position.x)
	global_position.x += speed * dir_to_crab * delta
	
	# Check if reached crab
	var dist_to_crab = abs(global_position.x - owner_crab.global_position.x)
	if dist_to_crab < return_threshold:
		returned_to_owner.emit()
		queue_free()


func _on_hit_area_2d_hitted(_area: Variant) -> void:
	pass


func _on_body_entered(_body: Node) -> void:
	pass
