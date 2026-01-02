extends EnemyState

## Windup anticipation — visual "tell" before throw
const WINDUP_SCALE: Vector2 = Vector2(1.15, 0.88)  ## Squat down
const NORMAL_SCALE: Vector2 = Vector2(1.0, 1.0)

func _enter() -> void:
	obj.change_animation("attack")
	obj.velocity.x = 0
	
	# Visual anticipation — squat before throw
	_apply_windup_anticipation()
	
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
	# Reset scale on exit
	var direction_node = obj.get_node_or_null("Direction")
	if direction_node:
		direction_node.scale = NORMAL_SCALE

func _on_windup_timer_timeout() -> void:
	if fsm.current_state == self:
		change_state(fsm.states.attack)


## Windup anticipation — squat down before throw
func _apply_windup_anticipation() -> void:
	var direction_node = obj.get_node_or_null("Direction")
	if not direction_node:
		return
	
	# Quick squat down — "winding up"
	var tween = create_tween()
	tween.tween_property(direction_node, "scale", WINDUP_SCALE, 0.1).set_ease(Tween.EASE_OUT)
