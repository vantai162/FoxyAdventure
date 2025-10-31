extends Area2D
@export var player:Player
func _on_area_entered(area: Area2D) -> void:
	print(area)
	if(area.get_parent().name=="Foxy"):
		area.get_parent()._collect_blade()
		queue_free()
	pass # Replace with function body.
