extends EnemyState
## Mushroom Kamikaze Hunt State
## Active threat: Chases player to explode
## Memory system: Continues to last known position, then returns to sleep if player gone
## Death condition: Any death scenario ALWAYS results in explosion (no other death path)

@export var chase_speed: float = 180.0  ## Slower than player (300) - escapable but threatening
@export var hunt_timeout: float = 8.0  ## Return to sleep after 8s of failed hunting
@export var destination_threshold: float = 20.0  ## "Close enough" to last known position

var last_known_position: Vector2 = Vector2.ZERO
var hunt_timer: float = 0.0
var is_hunting_memory: bool = false  ## Tracking ghost vs active player

func _enter() -> void:
	obj.change_animation("run")
	hunt_timer = 0.0
	is_hunting_memory = false
	
	# Store initial player position
	if obj.found_player:
		last_known_position = obj.found_player.global_position

func _update(delta):
	hunt_timer += delta
	
	# Timeout: Been hunting too long with no player → give up, return to sleep
	if hunt_timer >= hunt_timeout:
		if fsm.states.has("sleep"):
			change_state(fsm.states.sleep)
		return
	
	# Active player tracking
	if obj.found_player != null:
		# Update memory with current position
		last_known_position = obj.found_player.global_position
		is_hunting_memory = false
		hunt_timer = 0.0  # Reset timeout while actively tracking player
		_chase_target(last_known_position)
	else:
		# Player escaped detection → pursue last known position (sentience)
		is_hunting_memory = true
		_chase_target(last_known_position)
		
		# Reached ghost position but player not there → investigated, go back to sleep
		var distance_to_target = obj.global_position.distance_to(last_known_position)
		if distance_to_target < destination_threshold:
			# Mushroom: "I checked where they were... nothing here. Back to sleep."
			if fsm.states.has("sleep"):
				change_state(fsm.states.sleep)

func _chase_target(target_pos: Vector2) -> void:
	## Kamikaze pursuit: Move toward target position
	var to_target = target_pos - obj.global_position
	
	# Face target direction
	if to_target.x > 0 and obj.direction != 1:
		obj.turn_around()
	elif to_target.x < 0 and obj.direction != -1:
		obj.turn_around()
	
	# Move toward target (KAMIKAZE: toward, not away!)
	obj.velocity.x = obj.direction * chase_speed
