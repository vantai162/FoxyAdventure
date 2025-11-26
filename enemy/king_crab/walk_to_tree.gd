extends EnemyState

## Walk to nearest coconut tree, then climb up

# King Crab attacks cannot be interrupted - take damage but keep attacking
func take_damage(_damage_dir, damage: int) -> void:
	obj.take_damage(damage)

var target_tree: Node2D = null
var stuck_timer: float = 0.0
var last_x: float = 0.0

func _enter() -> void:
	obj.change_animation("run")
	target_tree = obj.find_nearest_tree()
	stuck_timer = 0.0
	last_x = obj.global_position.x
	
	if not target_tree:
		change_state(fsm.states.idle)

func _update(delta: float) -> void:
	if not target_tree or not is_instance_valid(target_tree):
		change_state(fsm.states.idle)
		return
	
	# Check if reached tree - only check HORIZONTAL distance (X axis)
	var horizontal_dist = abs(obj.global_position.x - target_tree.global_position.x)
	if horizontal_dist < 20.0:
		obj.set_meta("target_tree", target_tree)
		change_state(fsm.states.climbtree)
		return
	
	# Move toward tree
	var dir_to_tree = sign(target_tree.global_position.x - obj.global_position.x)
	if dir_to_tree != obj.direction:
		obj.turn_around()
	
	obj.velocity.x = obj.direction * obj.movement_speed
	
	# Stuck detection - if we haven't moved much, increment timer
	var moved = abs(obj.global_position.x - last_x)
	if moved < 2.0:
		stuck_timer += delta
		if stuck_timer >= obj.walk_stuck_timeout:
			# Give up and do something else
			change_state(fsm.states.idle)
			return
	else:
		stuck_timer = 0.0
		last_x = obj.global_position.x
