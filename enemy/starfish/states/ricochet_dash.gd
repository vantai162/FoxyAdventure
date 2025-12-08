extends EnemyState
## Elite Starfish "Ricochet Dash" state
## X-PATTERN: 3 sequential diagonal dashes in fixed 45° angles (↗️ ↘️ ↖️ ↙️)
## First dash ALWAYS goes UP to avoid ground-kissing (anti-gravity launch)
## Collision triggers next dash early, otherwise distance/time based

@export var dash_speed: float = 450.0  ## Fast dash speed
@export var max_dashes: int = 3  ## Triple dash sequence
@export var dash_distance: float = 150.0  ## Target distance per dash
@export var prepare_time: float = 0.15  ## Brief windup before first dash
@export var dash_pause: float = 0.15  ## Pause between dashes

## Note: Sequence state now lives in parent (obj) for persistence across frames

func _enter() -> void:
	obj.change_animation("attack")
	
	# Initialize sequence state in parent (persists across frames)
	obj.is_preparing = true
	obj.is_pausing = false
	obj.prepare_timer = prepare_time
	obj.current_dash = 0
	obj.dash_timer = 0.0
	obj.is_in_sequence = true
	obj.attack_cooldown_timer = obj.attack_cooldown
	obj.last_collision_normal = Vector2.ZERO  # Track collision for smart direction changes
	
	# Calculate dash direction toward player (or facing direction if no player)
	_calculate_dash_direction()
	
	# Stop movement during prepare
	obj.velocity = Vector2.ZERO
	
	# Enable HitArea for entire dash sequence
	_enable_hit_area(true)

func _exit() -> void:
	# Disable HitArea and restore gravity
	_enable_hit_area(false)
	obj.velocity = Vector2.ZERO
	
	# Notify parent that sequence is complete (parent manages cooldown/detection)
	if obj.has_method("on_sequence_complete"):
		obj.on_sequence_complete()
	# DON'T re-enable detection here - parent handles it after cooldown expires

func _update(delta: float) -> void:
	obj.dash_timer += delta
	
	# Phase 1: Prepare (brief windup before first dash)
	if obj.is_preparing:
		obj.prepare_timer -= delta
		obj.velocity = Vector2.ZERO  # Stay still during prepare
		if obj.prepare_timer <= 0.0:
			obj.is_preparing = false
			_start_dash()
		return
	
	# Phase 2: Pause between dashes
	if obj.is_pausing:
		obj.pause_timer -= delta
		obj.velocity = Vector2.ZERO  # Stay still during pause
		if obj.pause_timer <= 0.0:
			obj.is_pausing = false
			_start_dash()
		return
	
	# Phase 3: Active dash
	# Apply dash velocity (overwrites gravity)
	obj.velocity = obj.dash_direction * dash_speed
	
	# Check termination conditions for current dash:
	# 1. COLLISION with terrain - triggers next dash EARLY (your actual intent!)
	if obj.get_slide_collision_count() > 0:
		for i in range(obj.get_slide_collision_count()):
			var collision = obj.get_slide_collision(i)
			var normal = collision.get_normal()
			# Hit a solid surface (wall, floor, ceiling)
			if abs(normal.x) > 0.3 or abs(normal.y) > 0.3:
				# Store collision info for smart direction change
				obj.last_collision_normal = normal
				_end_current_dash()
				return
	
	# 2. Traveled target distance (fallback if no collision)
	var distance_traveled = obj.global_position.distance_to(obj.dash_start_position)
	if distance_traveled >= dash_distance:
		_end_current_dash()
		return
	
	# 3. Timeout failsafe (3 seconds total for entire sequence)
	if obj.dash_timer >= 3.0:
		change_state(fsm.states.run)
		return

func _start_dash() -> void:
	## Start a new dash segment
	obj.dash_start_position = obj.global_position
	
	# CRITICAL: Recalculate direction toward player for THIS dash
	# This prevents wall-kissing by always aiming at current player position
	_calculate_dash_direction()
	
	# Apply dash velocity
	obj.velocity = obj.dash_direction * dash_speed

func _end_current_dash() -> void:
	## End current dash and start next one (or return to run)
	obj.current_dash += 1
	
	if obj.current_dash >= max_dashes:
		# All dashes complete - return to patrol
		change_state(fsm.states.run)
	else:
		# Start pause before next dash
		obj.is_pausing = true
		obj.pause_timer = dash_pause

func _calculate_dash_direction() -> void:
	## X-PATTERN DIAGONAL MOVEMENT (4 fixed directions, not pixel-perfect tracking)
	## Design: Starfish picks one of 4 diagonals based on player quadrant
	## First dash ALWAYS goes UP-diagonal (anti-gravity launch from ground)
	## SMART: If we hit a wall, flip direction to avoid repeating into same obstacle
	
	if obj.found_player and is_instance_valid(obj.found_player):
		var to_player = obj.found_player.global_position - obj.global_position
		
		# Update facing direction based on horizontal component
		if to_player.x > 0:
			obj.change_direction(1)
		elif to_player.x < 0:
			obj.change_direction(-1)
		
		# FIRST DASH: Always launch UP-diagonal toward player's horizontal side
		if obj.current_dash == 0:
			# Launch up-left or up-right based on where player is horizontally
			if to_player.x >= 0:
				obj.dash_direction = Vector2(1, -1).normalized()  # Up-right ↗️
			else:
				obj.dash_direction = Vector2(-1, -1).normalized()  # Up-left ↖️
		else:
			# SUBSEQUENT DASHES: Pick diagonal based on player's quadrant
			# BUT if we just hit a collision, use the collision normal to bounce away smartly
			if obj.last_collision_normal.length() > 0.1:
				# We hit something! Reflect our last direction off the collision normal
				var reflected = obj.dash_direction.bounce(obj.last_collision_normal)
				
				# Snap to nearest diagonal (maintain X-pattern)
				var horizontal = 1 if reflected.x >= 0 else -1
				var vertical = -1 if reflected.y < 0 else 1
				obj.dash_direction = Vector2(horizontal, vertical).normalized()
				obj.last_collision_normal = Vector2.ZERO  # Clear collision memory
			else:
				# No recent collision, use player quadrant
				var horizontal = 1 if to_player.x >= 0 else -1  # Right or left?
				var vertical = -1 if to_player.y < 0 else 1      # Up or down?
				obj.dash_direction = Vector2(horizontal, vertical).normalized()
	else:
		# No player: Use smart fallback
		if obj.current_dash == 0:
			# First dash always up
			obj.dash_direction = Vector2(obj.direction, -1).normalized()
		else:
			# Subsequent dashes: if we hit something, bounce away; otherwise keep going
			if obj.last_collision_normal.length() > 0.1:
				var reflected = obj.dash_direction.bounce(obj.last_collision_normal)
				var horizontal = 1 if reflected.x >= 0 else -1
				var vertical = -1 if reflected.y < 0 else 1
				obj.dash_direction = Vector2(horizontal, vertical).normalized()
				obj.last_collision_normal = Vector2.ZERO
			else:
				# No collision, no player—just flip vertical to create X-pattern
				var new_vertical = -obj.dash_direction.y  # Flip up/down
				obj.dash_direction = Vector2(obj.dash_direction.x, new_vertical).normalized()

func _direction_name(h: int, v: int) -> String:
	if h > 0 and v < 0:
		return "UP-RIGHT ↗️"
	elif h < 0 and v < 0:
		return "UP-LEFT ↖️"
	elif h > 0 and v > 0:
		return "DOWN-RIGHT ↘️"
	else:
		return "DOWN-LEFT ↙️"

func _enable_hit_area(enabled: bool) -> void:
	## Toggle HitArea collision (active during entire dash sequence)
	if obj.has_node("Direction/HitArea2D/CollisionShape2D"):
		var collision_shape = obj.get_node("Direction/HitArea2D/CollisionShape2D")
		collision_shape.disabled = !enabled
