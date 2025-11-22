extends EnemyState

# Throw coconuts at player from tree

var throw_count: int = 0
var max_throws: int = 3
var throw_interval: float = 1.0
var time_since_throw: float = 0.0

func _enter() -> void:
	obj.change_animation("throw")
	throw_count = 0
	time_since_throw = 0.0
	if obj.current_phase == 2:
		max_throws = 5  # More coconuts in phase 2

func _update(delta: float) -> void:
	time_since_throw += delta
	
	if time_since_throw >= throw_interval:
		_throw_coconut()
		throw_count += 1
		time_since_throw = 0.0
		
		if throw_count >= max_throws:
			_descend_and_return()

func _throw_coconut() -> void:
	if obj.coconut_factory and obj.coconut_factory.has_method("create"):
		var coconut = obj.coconut_factory.create()
		if coconut:
			# Aim toward player if present
			if obj.found_player:
				var dir_to_player = (obj.found_player.global_position - coconut.global_position).normalized()
				coconut.linear_velocity = dir_to_player * 300.0
			else:
				# Random arc
				coconut.linear_velocity = Vector2(randf_range(-100, 100), -200)

func _descend_and_return() -> void:
	# Move back to ground
	obj.global_position.y += 150.0
	obj.can_throw_coconut = false
	get_tree().create_timer(5.0).timeout.connect(func(): obj.can_throw_coconut = true)
	change_state(fsm.states.idle)
