extends EnemyState
## Elite Spawner Mushroom pursuit state
## Slow menacing approach toward player (maintains pressure without overwhelming)

@export var pursuit_speed_multiplier: float = 0.8  ## Slower than run (80% speed)

func _enter() -> void:
	obj.change_animation("run")

func _update(_delta: float) -> void:
	if not obj.found_player or not is_instance_valid(obj.found_player):
		# Lost player, return to patrol
		change_state(fsm.states.run)
		return
	
	var to_player = obj.found_player.global_position - obj.global_position
	
	# Face player
	if to_player.x > 0 and obj.direction != 1:
		obj.change_direction(1)
	elif to_player.x < 0 and obj.direction != -1:
		obj.change_direction(-1)
	
	# Move toward player (slow menacing approach)
	obj.velocity.x = obj.direction * obj.movement_speed * pursuit_speed_multiplier
	
	# Respect walls and edges
	if obj.is_touch_wall():
		obj.velocity.x = 0
	elif obj.is_on_floor() and obj.is_can_fall():
		obj.velocity.x = 0
