extends RigidBody2D

@export var lifetime: float = 2.0
var timer: float = 0.0

func _process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		queue_free()
