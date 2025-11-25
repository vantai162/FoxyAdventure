extends EnemyState

## Climb coconut tree - tween position up to tree marker position
## Rotates crab sideways during climb for visual effect
## 
## ANIMATION ASSUMPTIONS:
##   - "climb" : Climbing motion, legs moving (loop: true)

@export var climb_duration: float = 1.8  ## Time to reach tree top (slower = more dramatic)

var climb_time: float = 0.0
var start_y: float = 0.0
var target_y: float = 0.0


func _enter() -> void:
	obj.change_animation("climb")  # Dedicated climbing animation
	obj.velocity = Vector2.ZERO
	climb_time = 0.0
	start_y = obj.global_position.y
	
	# Store ground Y for descent later
	obj.set_meta("ground_y", start_y)
	
	# Rotate sideways based on direction - crab "walks up" the tree
	# direction = 1 (facing right): rotate -90° so crab walks up on right side
	# direction = -1 (facing left): rotate 90° so crab walks up on left side
	obj.get_node("Direction").rotation_degrees = -90.0 * obj.direction
	
	# Get tree position from metadata (set by walk_to_tree)
	if obj.has_meta("target_tree"):
		var tree = obj.get_meta("target_tree")
		if is_instance_valid(tree):
			target_y = tree.global_position.y
		else:
			target_y = start_y - 150.0  # Fallback
	else:
		target_y = start_y - 150.0  # Fallback


func _update(delta: float) -> void:
	# Prevent gravity from pulling us down
	obj.velocity = Vector2.ZERO
	
	climb_time += delta
	
	# Smooth climb using ease out
	var progress = min(climb_time / climb_duration, 1.0)
	var eased = 1.0 - pow(1.0 - progress, 2)  # Ease out quad
	obj.global_position.y = lerp(start_y, target_y, eased)
	
	if progress >= 1.0:
		change_state(fsm.states.throwcoconuts)


func _exit() -> void:
	# Reset rotation to normal
	obj.get_node("Direction").rotation_degrees = 0.0
