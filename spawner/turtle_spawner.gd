extends Node2D

@onready var enemy = preload("res://enemy/turtle/turtle.tscn")
@onready var elite_enemy = preload("res://enemy/turtle/elite_spiny_turtle.tscn")
var elite_spawning = false



func _on_timer_timeout() -> void:
	if not elite_spawning:
		var ene = enemy.instantiate()
		ene.position = position
		get_parent().get_parent().get_node("Enemy").add_child(ene)
	else:
		var ene = elite_enemy.instantiate()
		ene.position = position
		get_parent().get_parent().get_node("Enemy").add_child(ene)
