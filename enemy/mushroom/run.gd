extends EnemyState
## Mushroom Kamikaze Hunt State
##
## DESIGN: "Moving to the disturbance"
## - If player VISIBLE: chase player directly (live position)
## - If player ESCAPED: chase disturbance_position (memory captured at detection)
## - On reaching memory position with no player: investigation complete → sleep
##
## GROUND-BASED: X-axis only for distance checks (can't fly)

@export var chase_speed: float = 180.0  ## Slower than player (300) - escapable but threatening
@export var hunt_timeout: float = 8.0  ## Return to sleep after failed hunting
@export var destination_threshold: float = 20.0  ## "Close enough" (X-axis only)

var hunt_timer: float = 0.0


func _enter() -> void:
	obj.change_animation("run")
	hunt_timer = 0.0
	
	if not obj.has_disturbance:
		push_warning("Mushroom run state entered without valid disturbance!")
		if fsm.states.has("sleep"):
			change_state(fsm.states.sleep)


func _update(delta: float) -> void:
	hunt_timer += delta
	
	# Timeout check
	if hunt_timer >= hunt_timeout:
		obj.clear_disturbance()
		if fsm.states.has("sleep"):
			change_state(fsm.states.sleep)
		return
	
	# Determine chase target: live player or memory
	var target_x: float
	if obj.found_player != null:
		# Player visible → chase directly, reset timeout
		target_x = obj.found_player.global_position.x
		hunt_timer = 0.0
	else:
		# Player escaped → chase memory
		target_x = obj.disturbance_position.x
	
	# Chase (X-axis only)
	var to_target_x := target_x - obj.global_position.x
	
	if to_target_x > 0 and obj.direction != 1:
		obj.turn_around()
	elif to_target_x < 0 and obj.direction != -1:
		obj.turn_around()
	
	obj.velocity.x = obj.direction * chase_speed
	
	# Reached destination check (only matters when chasing memory)
	if obj.found_player == null and absf(to_target_x) < destination_threshold:
		obj.clear_disturbance()
		if fsm.states.has("sleep"):
			change_state(fsm.states.sleep)
