extends Area2D

func _on_area_entered(area: Area2D) -> void:
	if !area.get_parent().checkfullhealth():
		area.get_parent().heal(1)
		queue_free()
	pass # Replace with function body.
