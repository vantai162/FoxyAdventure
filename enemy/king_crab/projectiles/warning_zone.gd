extends Node2D

# Temporary warning zone that disappears after a short time

@export var lifetime: float = 1.0

func _ready() -> void:
	# Fade out or blink effect could go here
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)
