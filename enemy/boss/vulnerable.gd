extends EnemyState

## Warlord Turtle Vulnerable State
## When at 1 HP, boss becomes defenseless — player can finish it
## VISUAL FEEDBACK: Pulsing/shaking to show weakness

var shake_timer: float = 0.0
var original_position: Vector2

func _enter():
	obj.change_animation("vulnerable")
	# DISABLE hurt area — boss cannot take damage in vulnerable state until mechanic resolved
	obj.get_node("Direction/HurtArea2D/CollisionShape2D").disabled = true
	obj.velocity.x = 0
	original_position = obj.position
	
	# Visual feedback: Pulsing weak color to show vulnerability
	_start_vulnerable_visual()

func _exit():
	# Restore position and visuals
	obj.position = original_position
	if obj.animated_sprite:
		obj.animated_sprite.modulate = Color.WHITE

func _update(delta: float) -> void:
	# Shake effect to show vulnerability/desperation
	shake_timer += delta
	obj.position = original_position + Vector2(
		randf_range(-2, 2),
		randf_range(-1, 1)
	)

## Visual feedback: Yellow-ish pulsing to show "finish me!" state
func _start_vulnerable_visual() -> void:
	if obj.animated_sprite == null:
		return
	var tween = obj.create_tween()
	tween.set_loops()
	# Pulse between yellow-white tones (weak/exposed look)
	tween.tween_property(obj.animated_sprite, "modulate", Color(1.2, 1.0, 0.6, 1.0), 0.3)
	tween.tween_property(obj.animated_sprite, "modulate", Color(1.0, 0.85, 0.5, 1.0), 0.3)
