extends pick_up_item
func _on_area_entered(area: Area2D) -> void:
	print(area)
	get_parent().get_node("EffectAppllier").ApplyEffect(effect_name,duration)
	queue_free()
	pass # Replace with function body.
