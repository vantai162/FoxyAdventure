extends Area2D
var is_collected = false 

func _on_area_entered(area: Area2D) -> void:
	if is_collected: return

	var parent = area.get_parent()
	if parent is Player:
		is_collected = true
		
		if parent.has_method("_collect_blade"):
			parent._collect_blade(true)
			
		queue_free()
