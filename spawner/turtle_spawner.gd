extends Node2D

@onready var enemy = preload("res://enemy/turtle/turtle.tscn")



func _on_timer_timeout() -> void:
	var ene = enemy.instantiate()
	ene.position = position
	get_parent().get_parent().get_node("Enemy").add_child(ene)
