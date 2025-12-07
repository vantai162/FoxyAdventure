extends EnemyState
## Elite Starfish "Ricochet Dash" state
## Master Yi style: 3 sequential dashes toward player, each ~100px
## Wall collision triggers next dash early, otherwise distance/time based

@export var dash_speed: float = 350.0  ## Fast dash speed
@export var max_dashes: int = 3  ## Triple dash sequence
@export var dash_distance: float = 100.0  ## Target distance per dash
@export var prepare_time: float = 0.15  ## Brief windup before first dash
@export var dash_pause: float = 0.1  ## Pause between dashes

var current_dash: int = 0  ## Which dash in sequence (0-2)
var dash_timer: float = 0.0
var prepare_timer: float = 0.0
var pause_timer: float = 0.0
var is_preparing: bool = true
var is_pausing: bool = false
var dash_direction: Vector2  ## Direction of current dash
var dash_start_position: Vector2  ## Start position of current dash segment

func _enter() -> void:
	obj.change_animation("attack")
	is_preparing = true
	is_pausing = false
	prepare_timer = prepare_time
	current_dash = 0
	dash_timer = 0.0
	
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
	
	# Re-enable detection after sequence completes
	if obj.has_method("enable_check_player_in_sight"):
		obj.enable_check_player_in_sight()

func _update(delta: float) -> void:
	dash_timer += delta
	
	# Phase 1: Prepare (brief windup before first dash)
	if is_preparing:
		prepare_timer -= delta
		obj.velocity = Vector2.ZERO  # Stay still during prepare
		if prepare_timer <= 0.0:
			is_preparing = false
			_start_dash()
		return
	
	# Phase 2: Pause between dashes
	if is_pausing:
		pause_timer -= delta
		obj.velocity = Vector2.ZERO  # Stay still during pause
		if pause_timer <= 0.0:
			is_pausing = false
			_start_dash()
		return
	
	# Phase 3: Active dash
	# Suppress gravity during dash by applying counter-force
	obj.velocity.y = min(obj.velocity.y, 0)  # Prevent falling, allow upward dash
	
	# Move in dash direction
	obj.velocity = dash_direction * dash_speed
	
	# Check termination conditions for current dash:
	# 1. Hit wall/terrain (collision)
	if obj.get_slide_collision_count() > 0:
		_end_current_dash()
		return
	
	# 2. Traveled target distance
	var distance_traveled = obj.global_position.distance_to(dash_start_position)
	if distance_traveled >= dash_distance:
		_end_current_dash()
		return
	
	# 3. Timeout failsafe (3 seconds total for entire sequence)
	if dash_timer >= 3.0:
		change_state(fsm.states.run)
		return

func _start_dash() -> void:
	## Start a new dash segment
	dash_start_position = obj.global_position
	
	# Recalculate direction toward player for this dash
	_calculate_dash_direction()
	
	# Apply dash velocity
	obj.velocity = dash_direction * dash_speed

func _end_current_dash() -> void:
	## End current dash and start next one (or return to run)
	current_dash += 1
	
	if current_dash >= max_dashes:
		# All dashes complete - return to patrol
		change_state(fsm.states.run)
	else:
		# Start pause before next dash
		is_pausing = true
		pause_timer = dash_pause

func _calculate_dash_direction() -> void:
	## Calculate diagonal/chaotic dash direction (not directly toward player)
	## Mix facing direction with vertical component for unpredictability
	if obj.found_player and is_instance_valid(obj.found_player):
		var to_player = obj.found_player.global_position - obj.global_position
		
		# Update facing direction based on horizontal component
		if to_player.x > 0:
			obj.change_direction(1)
		elif to_player.x < 0:
			obj.change_direction(-1)
		
		# Create diagonal dash: use facing direction + vertical component toward player
		# This creates chaotic diagonal movement instead of direct tracking
		var vertical_component = sign(to_player.y)  # -1 (up) or +1 (down)
		dash_direction = Vector2(obj.direction, vertical_component).normalized()
	else:
		# No player: dash diagonally in facing direction (fixed 45-degree down)
		dash_direction = Vector2(obj.direction, 1.0).normalized()

func _enable_hit_area(enabled: bool) -> void:
	## Toggle HitArea collision (active during entire dash sequence)
	if obj.has_node("Direction/HitArea2D/CollisionShape2D"):
		var collision_shape = obj.get_node("Direction/HitArea2D/CollisionShape2D")
		collision_shape.disabled = !enabled
