extends EnemyState

## Warlord Turtle Vulnerable State
## When at 1 HP, boss becomes defenseless — player can finish it
## VISUAL FEEDBACK: Pulsing/shaking to show weakness
##
## MECHANIC: Boss's hurt area is RE-ENABLED after a delay, allowing player to deal final blow.
## This creates a "finish him!" moment.

var shake_timer: float = 0.0
var original_position: Vector2
var _visual_tween: Tween = null  ## Store to kill on exit
var _vulnerable_delay: float = 1.5  ## Time before boss can be killed


func _enter():
	obj.change_animation("vulnerable")
	obj.velocity.x = 0
	original_position = obj.position
	shake_timer = 0.0
	
	# Visual feedback: Pulsing weak color to show vulnerability
	_start_vulnerable_visual()
	
	# RE-ENABLE hurt area after delay so player can finish the boss
	# GUARDED: Only enable if still in vulnerable state (boss not killed during delay)
	await get_tree().create_timer(_vulnerable_delay).timeout
	if fsm.current_state == self and is_instance_valid(obj):
		obj.get_node("Direction/HurtArea2D/CollisionShape2D").disabled = false


func _exit():
	# Kill the looping tween
	if _visual_tween and _visual_tween.is_valid():
		_visual_tween.kill()
		_visual_tween = null
	
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
	_visual_tween = obj.create_tween()
	_visual_tween.set_loops()
	# Pulse between yellow-white tones (weak/exposed look)
	_visual_tween.tween_property(obj.animated_sprite, "modulate", Color(1.2, 1.0, 0.6, 1.0), 0.3)
	_visual_tween.tween_property(obj.animated_sprite, "modulate", Color(1.0, 0.85, 0.5, 1.0), 0.3)
