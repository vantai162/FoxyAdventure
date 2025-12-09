extends EnemyState

func _enter() -> void:
	obj.change_animation("attack")
	obj.velocity.x = 0
	
	# Store last known player info for attack commitment
	if obj.found_player:
		obj.last_known_player_pos = obj.found_player.global_position
		obj.last_known_player_dir = 1 if obj.found_player.global_position.x > obj.global_position.x else -1
		obj.change_direction(obj.last_known_player_dir)
	else:
		# No player, use current direction
		obj.last_known_player_pos = obj.global_position + Vector2(obj.direction * 200, 0)
		obj.last_known_player_dir = obj.direction
	
	# Commit to attack - will complete at least 1 throw
	obj.is_committed_to_attack = true
	obj.windup_timer.start()

func _update(_delta: float) -> void:
	obj.velocity.x = 0

func _exit() -> void:
	obj.windup_timer.stop()

func _on_windup_timer_timeout() -> void:
	if fsm.current_state == self:
		change_state(fsm.states.attack)
