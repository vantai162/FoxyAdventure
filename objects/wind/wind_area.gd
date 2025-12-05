extends Area2D

@export var wind_force: Vector2 = Vector2(-150, 0)




func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	body.wind_velocity = wind_force


func _on_body_exited(body: Node2D) -> void:
	if body == null:
		return
	body.wind_velocity = Vector2.ZERO
