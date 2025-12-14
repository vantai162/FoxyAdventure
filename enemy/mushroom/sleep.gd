extends EnemyState
## Mushroom Sleep State - Peaceful until disturbed
##
## Clears any previous disturbance data on entry (fresh start)


func _enter() -> void:
	obj.change_animation("sleep")
	obj.clear_disturbance()  # Reset disturbance tracking
	
	# Show sleep icon, hide alert
	var sleep_icon = obj.get_node_or_null("Direction/SleepIcon")
	var alert_icon = obj.get_node_or_null("Direction/AlertIcon")
	if sleep_icon:
		sleep_icon.visible = true
	if alert_icon:
		alert_icon.visible = false


func _update(_delta: float) -> void:
	obj.velocity.x = 0
