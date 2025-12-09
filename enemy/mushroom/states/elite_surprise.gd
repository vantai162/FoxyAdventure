extends EnemyState
## Elite Spawner Mushroom Surprise State
## Alert reaction when player detected: show ! icon, FACE PLAYER, then pursue

@export var surprised_duration: float = 0.4  ## Quick alert (creature processing time)

func _enter() -> void:
	if obj.has_node("Direction/SleepIcon"):
		obj.get_node("Direction/SleepIcon").visible = false
	if obj.has_node("Direction/AlertIcon"):
		obj.get_node("Direction/AlertIcon").visible = true
	
	# CRITICAL: Face the player BEFORE spawning anything
	if obj.found_player and is_instance_valid(obj.found_player):
		var to_player = obj.found_player.global_position - obj.global_position
		if to_player.x > 0 and obj.direction != 1:
			obj.change_direction(1)
		elif to_player.x < 0 and obj.direction != -1:
			obj.change_direction(-1)
	
	obj.change_animation("run")
	timer = surprised_duration
	obj.velocity = Vector2.ZERO

func _update(delta):
	obj.velocity.x = 0
	if update_timer(delta):
		# Hide alert icon
		if obj.has_node("Direction/AlertIcon"):
			obj.get_node("Direction/AlertIcon").visible = false
		
		# Transition to pursuit
		if fsm.states.has("spawnerpursue"):
			change_state(fsm.states.spawnerpursue)
