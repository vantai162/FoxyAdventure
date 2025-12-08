extends EnemyState
## Elite Spawner Mushroom Run State
## Base mushroom uses: change_state(fsm.states.sleep)
## Elite spawner must use: change_state(fsm.states.spawnerpursue)

@export var follow_move: float = 250.0

func _enter() -> void:
	obj.change_animation("run")

func _update(delta):
	if obj.found_player == null:
		# Base mushroom: change_state(fsm.states.sleep)
		# Elite spawner: change to spawner_pursue or stay in run
		if fsm.states.has("spawnerpursue"):
			change_state(fsm.states.spawnerpursue)
		# Else: stay in run state (no crash)
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
