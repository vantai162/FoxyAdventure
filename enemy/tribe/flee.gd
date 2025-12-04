extends EnemyState

func _enter() -> void:
	obj.change_animation("run")

func _update(delta):
	if obj.found_player == null:
		change_state(fsm.states.run)
		return

	var player_pos = obj.found_player.global_position

	# Nếu enemy đang quay mặt về phía player thì quay lại
	if sign(player_pos.x - obj.global_position.x) == obj.direction:
		obj.turn_around()
	
	# If touching another enemy or wall while fleeing, stop
	if obj.is_touching_enemy() or obj.is_touch_wall():
		obj.velocity.x = 0
		return
	
	# If about to fall off edge, stop
	if obj.is_on_floor() and obj.is_can_fall():
		obj.velocity.x = 0
		return

	# Chạy trốn ngược hướng player
	obj.velocity.x = obj.direction * obj.movement_speed * 1.2

	# Nếu đã đủ xa thì quay lại tuần tra
	if obj.global_position.distance_to(player_pos) > 1000:
		change_state(fsm.states.run)
