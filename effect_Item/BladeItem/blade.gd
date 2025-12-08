extends Area2D

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is Player:
		parent._collect_blade()
		area.get_parent().inventory.adjust_amount_item("Blade",1)
		queue_free()
