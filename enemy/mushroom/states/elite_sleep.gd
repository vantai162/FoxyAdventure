extends EnemyState
## Elite Spawner Mushroom Sleep State
## Idle state when no player detected

func _enter() -> void:
	obj.change_animation("run")  ## Elite uses run animation as idle
	obj.velocity.x = 0
	
	# Show sleep icon
	if obj.has_node("Direction/SleepIcon"):
		obj.get_node("Direction/SleepIcon").visible = true
	if obj.has_node("Direction/AlertIcon"):
		obj.get_node("Direction/AlertIcon").visible = false

func _update(_delta):
	obj.velocity.x = 0
