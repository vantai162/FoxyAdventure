extends Area2D

## King Crab Claw - DOUBLE WRAP ATTACK
##
## KOJIMA DESIGN: The claw is a PREDATOR that circles the arena.
## 
## SEQUENCE (C = crab position, launched left toward edge A, B = opposite edge):
## 1. LAUNCH: C → A (normal speed, HIGH altitude, first pass)
## 2. WRAP #1: Hit A edge → TELEPORT to B edge, DROP LOW, speed UP, START persistent shake
## 3. PASS 2: B → A (fast, LOW altitude, ground scrape, world trembles)
## 4. WRAP #2: Hit A edge → TELEPORT to B edge, RISE HIGH, STOP shake, start RETURN
## 5. RETURN: B → C (seek crab directly, HIGH altitude, normal speed)
##
## HEIGHT MECHANICS:
## - Pass 1 & Return: launch_y = -28 (high, from factory)
## - Pass 2: low_y = -8 (ground scrape, offset +20 from launch_y)
##
## SHAKE MECHANICS:
## - One-shot shake on wrap 1
## - PERSISTENT shake during entire pass 2 (ground scrape terror)
## - Shake stops when return begins

signal returned_to_owner

# Settings - set by claw_attack.gd before setup()
var speed: float = 0.0
var travel_distance: float = 0.0  ## Half-width of the arena from crab center
var return_threshold: float = 0.0
var wrap_offset_ratio: float = 0.0
var second_wrap_speed_mult: float = 1.4
var second_wrap_shake: float = 6.0

# Height settings
const LOW_Y_OFFSET: float = 20.0  ## Drop from -28 to -8 (ground scrape height)
const SCRAPE_SCALE_MULT: float = 1.15  ## Slightly bigger during ground scrape (menace)

# State
var launch_direction: int = 1  ## -1 = left, 1 = right (direction of first pass)
var owner_crab: Node2D = null
var launch_y: float = 0.0  ## High altitude (from factory position)
var low_y: float = 0.0  ## Low altitude for ground scrape
var crab_x_at_launch: float = 0.0  ## Crab's X when attack started (stable reference)
var original_scale: Vector2 = Vector2.ONE  ## Store original scale to preserve magnitude

var wrap_count: int = 0  ## 0 = first pass, 1 = after first wrap, 2+ = return phase
var is_returning: bool = false
var current_speed: float = 0.0
var is_ground_scraping: bool = false  ## True during the dangerous low pass

# Visual state (tracked separately for clean scale/facing updates)
var current_facing: int = 1  ## -1 = facing left, 1 = facing right
var current_scale_mult: float = 1.0  ## 1.0 = normal, 1.15 = scrape phase

# Arena bounds (FIXED at setup, calculated from crab's launch position)
var arena_left: float = 0.0
var arena_right: float = 0.0

# Persistent shake
var _shake_timer: float = 0.0
const SHAKE_INTERVAL: float = 0.08  ## Shake every 80ms for rumble effect
const SHAKE_INTENSITY: float = 4.0  ## Per-shake intensity during ground scrape

const MAX_LIFETIME: float = 15.0
var lifetime: float = 0.0


func setup(direction: int, crab: Node2D) -> void:
	launch_direction = direction if direction != 0 else 1
	owner_crab = crab
	launch_y = global_position.y  ## High altitude from factory
	low_y = launch_y + LOW_Y_OFFSET  ## Lower for ground scrape
	crab_x_at_launch = crab.global_position.x  ## Store for stable reference
	wrap_count = 0
	is_returning = false
	is_ground_scraping = false
	current_speed = speed
	lifetime = 0.0
	_shake_timer = 0.0
	
	# Store original scale BEFORE modifying (preserves the 2.2x from scene)
	original_scale = scale
	current_scale_mult = 1.0  # Reset to normal
	
	# STABLE ARENA BOUNDS: Fixed at launch time, never change
	# Arena is centered on crab's launch position, extends travel_distance in each direction
	arena_left = crab_x_at_launch - travel_distance
	arena_right = crab_x_at_launch + travel_distance
	
	# Visual: face launch direction
	_set_facing(launch_direction)


func _physics_process(delta: float) -> void:
	if HitstopManager.is_frozen(self):
		return
	
	lifetime += delta
	if lifetime > MAX_LIFETIME:
		queue_free()
		return
	
	# PERSISTENT SHAKE during ground scrape (pass 2)
	if is_ground_scraping:
		_shake_timer += delta
		if _shake_timer >= SHAKE_INTERVAL:
			_shake_timer = 0.0
			_do_persistent_shake()
	
	if is_returning:
		_do_return(delta)
	else:
		_do_wrap_pass(delta)


func _do_persistent_shake() -> void:
	## Continuous rumble during ground scrape — world trembles as claw drags
	if not owner_crab or not is_instance_valid(owner_crab):
		return
	var camera = owner_crab.get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(SHAKE_INTENSITY)


func _do_wrap_pass(delta: float) -> void:
	## Move in launch direction until hitting the FAR edge (in launch direction)
	global_position.x += current_speed * launch_direction * delta
	
	# Determine which edge we're heading toward
	var target_edge: float
	if launch_direction < 0:
		target_edge = arena_left  # Moving left, target left edge
	else:
		target_edge = arena_right  # Moving right, target right edge
	
	# Check if we've reached or passed the target edge
	var hit_edge := false
	if launch_direction < 0 and global_position.x <= target_edge:
		hit_edge = true
		global_position.x = target_edge  # Clamp to edge
	elif launch_direction > 0 and global_position.x >= target_edge:
		hit_edge = true
		global_position.x = target_edge  # Clamp to edge
	
	if hit_edge:
		_perform_wrap()


func _perform_wrap() -> void:
	if not owner_crab or not is_instance_valid(owner_crab):
		queue_free()
		return
	
	wrap_count += 1
	
	if wrap_count >= 2:
		# Two wraps complete — transition to return phase
		_start_return()
		return
	
	# WRAP TELEPORT: Move to the OPPOSITE edge, keep moving same direction
	if launch_direction < 0:
		# Was at left edge → teleport to right edge
		global_position.x = arena_right
	else:
		# Was at right edge → teleport to left edge
		global_position.x = arena_left
	
	# After first wrap: DROP LOW, SPEED UP, START GROUND SCRAPE
	if wrap_count == 1:
		# DROP to low altitude for ground scrape
		global_position.y = low_y
		is_ground_scraping = true
		_shake_timer = 0.0  # Reset shake timer
		
		# SCALE UP slightly — claw feels HEAVIER, more threatening
		_set_scale_mult(SCRAPE_SCALE_MULT)
		
		# Speed up for aggressive second pass
		current_speed = speed * second_wrap_speed_mult
		
		# Initial big shake to announce the drop
		var camera = owner_crab.get_viewport().get_camera_2d()
		if camera and camera.has_method("shake"):
			camera.shake(second_wrap_shake)
	else:
		global_position.y = launch_y  # Maintain high altitude


func _start_return() -> void:
	is_returning = true
	is_ground_scraping = false  # STOP the persistent shake
	current_speed = speed  # Return at base speed
	
	# SCALE BACK DOWN — scrape phase over
	_set_scale_mult(1.0)
	
	# TELEPORT to opposite edge — this is where return journey STARTS
	if launch_direction < 0:
		# We just hit left edge (again) → teleport to right edge to start return
		global_position.x = arena_right
	else:
		# We just hit right edge (again) → teleport to left edge to start return
		global_position.x = arena_left
	
	# RISE back to high altitude for return journey
	global_position.y = launch_y
	
	# Face toward crab (opposite of launch direction)
	_set_facing(-launch_direction)


func _do_return(delta: float) -> void:
	if not owner_crab or not is_instance_valid(owner_crab):
		queue_free()
		return
	
	# SEEK THE CRAB: Move directly toward owner's CURRENT position
	var crab_pos = owner_crab.global_position
	var dir_to_crab = sign(crab_pos.x - global_position.x)
	
	# Handle edge case: claw is exactly at crab x
	if dir_to_crab == 0:
		dir_to_crab = -launch_direction  # Default to returning opposite of launch
	
	# Move toward crab
	global_position.x += current_speed * dir_to_crab * delta
	
	# Update visual to face movement direction (preserve scale magnitude)
	_set_facing(dir_to_crab)
	
	# Check if reached crab
	var dist_to_crab = abs(global_position.x - crab_pos.x)
	if dist_to_crab < return_threshold:
		returned_to_owner.emit()
		queue_free()


## Update visual scale based on current_facing and current_scale_mult
## Call this after changing either value
func _update_visual() -> void:
	scale.x = abs(original_scale.x) * current_scale_mult * current_facing
	scale.y = abs(original_scale.y) * current_scale_mult


## Set facing direction and update visual
func _set_facing(direction: int) -> void:
	current_facing = direction
	_update_visual()


## Set scale multiplier and update visual
func _set_scale_mult(mult: float) -> void:
	current_scale_mult = mult
	_update_visual()


func _on_hit_area_2d_hitted(_area: Variant) -> void:
	pass


func _on_body_entered(_body: Node) -> void:
	pass
