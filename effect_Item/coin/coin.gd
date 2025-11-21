extends Area2D
func _ready() -> void:
	$AnimatedSprite2D.play("default")
func _on_area_entered(area: Area2D) -> void:
	area.get_parent().inventory.adjust_amount_item("Coin",1)
	queue_free()
	pass # Replace with function body.
