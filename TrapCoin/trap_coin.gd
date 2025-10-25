extends Area2D

func _on_area_entered(area: Area2D) -> void:
	get_parent().get_node("EffectAppllier").ApplyEffect("Stun",2.0)
	queue_free()
	pass # Replace with function body.
