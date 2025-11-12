extends Area2D
class_name BladeContainer

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is Player:
		parent.increase_blade_capacity()
		queue_free()
