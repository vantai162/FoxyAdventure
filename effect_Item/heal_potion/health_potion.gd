extends Area2D

func _on_area_entered(area: Area2D) -> void:
	if !area.get_parent().checkfullhealth():
		hide()
		AudioManager.play_sound("heal",20.0)
		area.get_parent().heal(1)
		queue_free()
	
