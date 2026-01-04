extends Area2D

## King Crab claw projectile - DOUBLE WRAP attack
## 
## DESIGN: The claw wraps around the screen TWICE before returning.
## - First wrap: Normal speed, establishes the threat
## - Second wrap: FASTER (1.4x), screen shake warning
## - Then returns to boss who gets a LONGER stun (trade-off)
##
## Direction NEVER changes. If thrown right, always moves right.
## Wrap = exit right edge, appear on left edge, continue right.

signal returned_to_owner  ## Emitted when claw reaches the crab

# Movement settings - set by claw_attack state before calling setup()
var speed: float = 0.0
var travel_distance: float = 0.0
var return_threshold: float = 0.0
var wrap_offset_ratio: float = 0.0
var second_wrap_speed_mult: float = 1.4  ## Second wrap is faster
var second_wrap_shake: float = 6.0  ## Screen shake on second wrap

var launch_direction: int = 1
var owner_crab: Node2D = null
var wrap_start_x: float = 0.0  ## Reset each wrap
var launch_y: float = 0.0  ## Keep Y constant throughout flight

var wrap_count: int = 0  ## How many times we've wrapped (0, 1, 2)
var is_returning: bool = false
var current_speed: float = 0.0  ## Actual speed (increases after second wrap)

const MAX_LIFETIME: float = 12.0  ## Slightly longer for double wrap
var lifetime: float = 0.0


func setup(direction: int, crab: Node2D) -> void:
	## Called by claw_attack state after spawning
	launch_direction = direction if direction != 0 else 1
	owner_crab = crab
	wrap_start_x = global_position.x
	launch_y = global_position.y
	wrap_count = 0
	is_returning = false
	current_speed = speed  ## Start at base speed
	
	# Standard codebase pattern: scale.x = direction (1=right, -1=left)
	scale.x = launch_direction


func _physics_process(delta: float) -> void:
	# Hitstop: freeze in place when hit lands
	if HitstopManager.is_frozen(self):
		return
	
	lifetime += delta
	if lifetime > MAX_LIFETIME:
		queue_free()
		return
	
	if not is_returning:
		_do_wrap_pass(delta)
	else:
		_do_return(delta)


func _do_wrap_pass(delta: float) -> void:
	## Move in launch direction, wrap when traveled far enough
	global_position.x += current_speed * launch_direction * delta
	
	# Check if traveled far enough for a wrap
	var traveled = abs(global_position.x - wrap_start_x)
	if traveled >= travel_distance:
		_perform_wrap()


func _perform_wrap() -> void:
	if not owner_crab or not is_instance_valid(owner_crab):
		queue_free()
		return
	
	wrap_count += 1
	
	if wrap_count >= 2:
		# Two wraps done — now return to boss
		_start_return()
		return
	
	# First wrap done, prepare for second wrap
	# Teleport to opposite side (behind where claw came from)
	var offset = travel_distance * wrap_offset_ratio * -launch_direction
	global_position.x = owner_crab.global_position.x + offset
	global_position.y = launch_y  ## Keep original height
	wrap_start_x = global_position.x  ## Reset distance tracking
	
	# Second wrap is FASTER — escalation!
	current_speed = speed * second_wrap_speed_mult
	
	# Screen shake to telegraph: "Here comes the real threat!"
	var camera = owner_crab.get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(second_wrap_shake)
	
	# Direction stays the SAME — no flip
	# scale.x already set to launch_direction


func _start_return() -> void:
	is_returning = true
	
	# Teleport behind boss for return journey
	var offset = travel_distance * wrap_offset_ratio * -launch_direction
	global_position.x = owner_crab.global_position.x + offset
	global_position.y = launch_y
	
	# Return speed is base speed (not the fast second-wrap speed)
	current_speed = speed
	
	# NOW flip to face return direction (toward boss)
	var return_dir = sign(owner_crab.global_position.x - global_position.x)
	scale.x = return_dir


func _do_return(delta: float) -> void:
	if not owner_crab or not is_instance_valid(owner_crab):
		queue_free()
		return
	
	# Move toward crab
	var dir_to_crab = sign(owner_crab.global_position.x - global_position.x)
	global_position.x += current_speed * dir_to_crab * delta
	
	# Check if reached crab
	var dist_to_crab = abs(global_position.x - owner_crab.global_position.x)
	if dist_to_crab < return_threshold:
		returned_to_owner.emit()
		queue_free()


func _on_hit_area_2d_hitted(_area: Variant) -> void:
	pass


func _on_body_entered(_body: Node) -> void:
	pass
