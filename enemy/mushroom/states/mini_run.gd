extends EnemyState
## Mini Mushroom Run State
## Always active, no sleep state - just patrol until player detected

@export var follow_move: float = 250.0

func _enter() -> void:
	obj.change_animation("run")

func _update(_delta):
	# Mini mushrooms don't sleep, they stay active
	# If player found, move toward them (kamikaze approach)
	if obj.found_player != null:
		var player_pos = obj.found_player.global_position
		
		# Face player
		if sign(player_pos.x - obj.global_position.x) != obj.direction:
			obj.turn_around()
		
		# Run toward player (flee behavior inverted for kamikaze)
		obj.velocity.x = obj.direction * follow_move
	else:
		# No player: simple patrol
		obj.velocity.x = obj.direction * obj.movement_speed
		
		# Turn around at obstacles
		if _should_turn_around():
			obj.turn_around()

func _should_turn_around() -> bool:
	if obj.is_touch_wall():
		return true
	if obj.is_on_floor() and obj.is_can_fall():
		return true
	return false
