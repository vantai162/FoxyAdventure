extends Camera2D

var shake_strength: float = 0.0
var shake_decay: float = 5.0  
var shake_offset := Vector2.ZERO

func _process(delta: float) -> void:
	if shake_strength > 0:
		shake_offset = Vector2(
			randf_range(-1, 1),
			randf_range(-1, 1)
		) * shake_strength
		offset = shake_offset
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
	else:
		offset = Vector2.ZERO

func shake(amount: float = 10.0):
	shake_strength = amount
