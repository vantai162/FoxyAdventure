extends Camera2D
class_name ShakeableCamera

## A Camera2D with screen shake support.
## Use this script on any Camera2D (player camera, fixed arena camera, etc.)
## Call shake(amount) to trigger shake effect.

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


func shake(amount: float = 10.0) -> void:
	shake_strength = amount
