extends Node2D
@onready var obj = preload("res://effect_Item/heal_potion/health_potion.tscn")


func _on_timer_timeout() -> void:
	print("spawn potion")
	var obj = obj.instantiate()
	obj.position = position
	get_parent().get_node("Potion").add_child(obj)
