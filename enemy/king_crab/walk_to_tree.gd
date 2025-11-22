extends EnemyState

# Walk to nearest coconut tree

func _enter() -> void:
	obj.change_animation("run")
	if not obj.target_tree:
		change_state(fsm.states.idle)
		return

func _update(delta: float) -> void:
	if not obj.target_tree:
		change_state(fsm.states.idle)
		return
	
	# Check if reached tree
	if obj.is_at_tree():
		change_state(fsm.states.climb_tree)
		return
	
	# Move toward tree
	var direction_to_tree = sign(obj.target_tree.global_position.x - obj.global_position.x)
	if direction_to_tree != obj.direction:
		obj.turn_around()
	
	obj.velocity.x = obj.direction * obj.walk_speed
	
	# Handle obstacles
	if obj.is_touch_wall() or (obj.is_on_floor() and obj.is_can_fall()):
		# Try to find another tree
		obj.target_tree = obj.find_nearest_tree()
		if not obj.target_tree:
			change_state(fsm.states.idle)
