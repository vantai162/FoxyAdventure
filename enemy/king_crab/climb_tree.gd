extends EnemyState

# Climb coconut tree animation and position

var climb_time: float = 0.0
var climb_duration: float = 2.0  # Time to reach top
var start_y: float = 0.0
var target_y_offset: float = -150.0  # Climb 150 pixels up

func _enter() -> void:
	obj.change_animation("climb")
	obj.velocity = Vector2.ZERO
	climb_time = 0.0
	start_y = obj.global_position.y

func _update(delta: float) -> void:
	climb_time += delta
	
	# Interpolate climb
	var progress = min(climb_time / climb_duration, 1.0)
	obj.global_position.y = start_y + (target_y_offset * progress)
	
	if progress >= 1.0:
		change_state(fsm.states.throw_coconuts)

func _exit() -> void:
	# Reset to ground level when done
	pass
