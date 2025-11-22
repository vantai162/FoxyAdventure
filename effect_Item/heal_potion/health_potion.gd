extends Area2D

func _on_area_entered(area: Area2D) -> void:
	if !area.get_parent().checkfullhealth():
		hide()
		$AudioStreamPlayer.play()
		area.get_parent().heal(1)
		await $AudioStreamPlayer.finished
		queue_free()
	pass # Replace with function body.
