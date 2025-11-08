extends EnemyState


func _enter() -> void:
	print("run")
	obj.change_animation("run")


func _update(_delta):
	super._update(_delta)
	obj.velocity.x = obj.direction * obj.movement_speed
	
	if _should_turn_around():
		obj.turn_around()

	if obj.found_player:
		if obj.found_player.global_position.x > obj.global_position.x:
			obj.turn_right()
		else:
			obj.turn_left()
		change_state(fsm.states.attack)


func _should_turn_around() -> bool:
	if obj.is_touch_wall():
		return true
	
	return false
