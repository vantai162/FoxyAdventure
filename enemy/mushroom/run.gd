extends EnemyState
@export var follow_move: float = 250.0
func _enter() -> void:
	obj.change_animation("run")

func _update(delta):
	
	if obj.found_player == null:
		print("het")
		change_state(fsm.states.sleep)
		return

	var player_pos = obj.found_player.global_position

	# Nếu enemy đang quay mặt về phía player thì quay lại
	if sign(player_pos.x - obj.global_position.x) != obj.direction:
		obj.turn_around()

	# Chạy trốn ngược hướng player
	obj.velocity.x = obj.direction * follow_move
	
	
	

func _should_turn_around() -> bool:
	if obj.is_touch_wall():
		return true
	if obj.is_on_floor() and obj.is_can_fall():
		return true
	return false
