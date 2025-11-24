extends pick_up_item
func _ready() -> void:
	$AnimatedSprite2D.play("default")
func _on_area_entered(area: Area2D) -> void:
	print(area)
	area.get_parent()._applyeffect(effect_name,duration)
	queue_free()
	pass # Replace with function body.
