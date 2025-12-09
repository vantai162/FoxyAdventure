extends EnemyState
## Elite Spawner Mushroom pursuit state
## Strategic distance-keeping: Artillery commander positioning
## NOT melee - maintains spawn range while saturating area with minis

@export var preferred_distance: float = 120.0  ## Sweet spot artillery range
@export var flee_threshold: float = 70.0       ## Too close — retreat!
@export var pursuit_speed: float = 160.0       ## Moderate pursuit (strategic, not aggressive)
@export var flee_speed: float = 220.0          ## Fast retreat (protect the spawner!)
@export var jump_cooldown: float = 2.0         ## Time between jumps
@export var jump_distance_threshold: float = 80.0   ## Jump when this close horizontally
@export var jump_distance_max: float = 200.0   ## Don't jump if player too far

var jump_timer: float = 0.0

func _enter() -> void:
	obj.change_animation("run")
	jump_timer = 0.0  # Can jump immediately on entry

func _update(delta: float) -> void:
	# Update jump timer
	if jump_timer > 0.0:
		jump_timer -= delta
	
	if not obj.found_player or not is_instance_valid(obj.found_player):
		# Lost player → return to sleep (no persistence yet)
		if fsm.states.has("sleep"):
			change_state(fsm.states.sleep)
		return
	
	var to_player = obj.found_player.global_position - obj.global_position
	var horizontal_distance = abs(to_player.x)
	var vertical_distance = to_player.y  # Negative if player above
	
	# Always face player
	if to_player.x > 0 and obj.direction != 1:
		obj.change_direction(1)
	elif to_player.x < 0 and obj.direction != -1:
		obj.change_direction(-1)
	
	# Jump logic: Jump when player is above OR at vertical obstacle
	if obj.is_on_floor() and jump_timer <= 0.0:
		# Jump if player is significantly above us
		if vertical_distance < -50.0 and horizontal_distance <= jump_distance_max:
			_perform_jump(to_player)
		# Or jump if at horizontal range but can't reach (wall blocking)
		elif obj.is_touch_wall() and horizontal_distance <= jump_distance_max:
			_perform_jump(to_player)
	
	# Use HORIZONTAL distance for positioning (ignore vertical)
	# This allows pursuit even when player on ledge
	if horizontal_distance < flee_threshold:
		# FLEE: Player too close
		obj.velocity.x = -obj.direction * flee_speed
	elif horizontal_distance > preferred_distance:
		# PURSUE: Player too far
		obj.velocity.x = obj.direction * pursuit_speed
	else:
		# HOLD: Optimal range
		obj.velocity.x = 0
	
	# Respect walls (stop if blocked)
	if obj.is_touch_wall() and not (obj.is_on_floor() and jump_timer <= 0.0):
		obj.velocity.x = 0

func _perform_jump(to_player: Vector2) -> void:
	## Jump toward player to maintain artillery range
	var vertical_distance = abs(to_player.y)
	
	# Scale jump height based on how high player is (0.8x to 1.2x)
	var height_multiplier = clamp(0.8 + (vertical_distance / 200.0), 0.8, 1.2)
	var jump_height = obj.jump_speed * height_multiplier
	obj.velocity.y = -jump_height
	
	# Add horizontal boost toward player (moderate - not aggressive melee)
	var horizontal_boost = sign(to_player.x) * obj.movement_speed * 1.2
	obj.velocity.x += horizontal_boost
	
	jump_timer = jump_cooldown
