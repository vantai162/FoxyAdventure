extends Area2D

## King Crab HUNTER CLAW - A predator that tracks and threatens
## 
## KOJIMA DESIGN: "The claw should feel ALIVE — hunting, tracking, relentless."
## - Tracks player's Y position during outbound flight
## - Returns on a different height (boomerang pattern)
## - Scales up during flight for visual WEIGHT
## - No wrap-around — direct boomerang return

signal returned_to_owner  ## Emitted when claw reaches the crab

# Movement settings - set by claw_attack state before calling setup()
var speed: float = 500.0
var travel_distance: float = 600.0
var return_threshold: float = 60.0
var tracking_speed: float = 200.0  ## Vertical tracking speed
var tracking_range: float = 120.0  ## Max vertical deviation from launch height
var return_height_offset: float = 64.0  ## Return at different height
var scale_max: float = 1.4  ## Grow during flight

var is_returning: bool = false
var launch_direction: int = 1
var owner_crab: Node2D = null
var target_player: Node2D = null  ## Track the player!
var launch_position: Vector2 = Vector2.ZERO
var launch_y: float = 0.0
var return_y: float = 0.0  ## Different Y for return path
var base_scale: Vector2 = Vector2.ONE

const MAX_LIFETIME: float = 8.0
var lifetime: float = 0.0
var flight_progress: float = 0.0  ## 0-1 for scaling


func setup(direction: int, crab: Node2D, player: Node2D = null) -> void:
	## Called by claw_attack state after spawning
	launch_direction = direction if direction != 0 else 1
	owner_crab = crab
	target_player = player
	launch_position = global_position
	launch_y = global_position.y
	is_returning = false
	lifetime = 0.0
	flight_progress = 0.0
	base_scale = scale
	
	# Calculate return height (offset from launch)
	# If player is above, return lower. If below, return higher. Creates X pattern.
	if target_player and is_instance_valid(target_player):
		var player_offset = target_player.global_position.y - launch_y
		return_y = launch_y - sign(player_offset) * return_height_offset
	else:
		return_y = launch_y - return_height_offset  ## Default: return higher
	
	# Standard codebase pattern: scale.x sign = direction (1=right, -1=left)
	scale.x = abs(scale.x) * launch_direction


func _physics_process(delta: float) -> void:
	# Hitstop: freeze in place when hit lands
	if HitstopManager.is_frozen(self):
		return
	
	lifetime += delta
	if lifetime > MAX_LIFETIME:
		queue_free()
		return
	
	if not is_returning:
		_do_hunt(delta)
	else:
		_do_return(delta)
	
	_update_scale()


func _do_hunt(delta: float) -> void:
	## HUNTING PHASE: Track player vertically while moving horizontally
	
	# Horizontal movement
	global_position.x += speed * launch_direction * delta
	
	# Vertical TRACKING - hunt the player's Y position
	if target_player and is_instance_valid(target_player):
		var target_y = target_player.global_position.y
		# Clamp to tracking range (don't deviate too far from launch height)
		target_y = clampf(target_y, launch_y - tracking_range, launch_y + tracking_range)
		
		# Smoothly track toward target Y
		var y_diff = target_y - global_position.y
		var y_move = sign(y_diff) * minf(abs(y_diff), tracking_speed * delta)
		global_position.y += y_move
	
	# Update flight progress for scaling
	var traveled = abs(global_position.x - launch_position.x)
	flight_progress = clampf(traveled / travel_distance, 0.0, 1.0)
	
	# Check if reached max distance - start return
	if traveled >= travel_distance:
		_start_return()


func _start_return() -> void:
	is_returning = true
	
	# Flip direction for return
	launch_direction = -launch_direction
	scale.x = abs(scale.x) * launch_direction
	
	# Snap to return height for the boomerang effect
	# Creates diagonal return path
	global_position.y = return_y


func _do_return(delta: float) -> void:
	if not owner_crab or not is_instance_valid(owner_crab):
		queue_free()
		return
	
	# Move toward crab
	var dir_to_crab = owner_crab.global_position - global_position
	var dist_to_crab = dir_to_crab.length()
	
	# Horizontal movement toward crab
	global_position.x += speed * sign(dir_to_crab.x) * delta
	
	# Vertical: smoothly descend/ascend to crab's Y
	var y_diff = owner_crab.global_position.y - global_position.y
	var y_speed = abs(y_diff) / maxf(dist_to_crab / speed, 0.1)  ## Match arrival time
	global_position.y += sign(y_diff) * minf(abs(y_diff), y_speed * delta)
	
	# Update flight progress (reverse for scaling down)
	flight_progress = clampf(dist_to_crab / travel_distance, 0.0, 1.0)
	
	# Check if reached crab
	if dist_to_crab < return_threshold:
		returned_to_owner.emit()
		queue_free()


func _update_scale() -> void:
	## Scale up during outbound, scale down during return
	## Creates sense of MOMENTUM and WEIGHT
	var scale_factor = lerpf(1.0, scale_max, flight_progress)
	scale = Vector2(sign(scale.x) * base_scale.x * scale_factor, base_scale.y * scale_factor)


func _on_hit_area_2d_hitted(_area: Variant) -> void:
	## Claw hit player - could add effects here
	pass


func _on_body_entered(_body: Node) -> void:
	pass
