extends Player_State

## Throw momentum preservation multiplier for ground throws
## 1.0 = full momentum, 0.5 = half speed, 0.0 = full stop
const GROUND_THROW_MOMENTUM_KEEP: float = 0.6

## Throw anticipation squash/stretch
const THROW_WINDUP: Vector2 = Vector2(1.1, 0.92)
const THROW_RELEASE: Vector2 = Vector2(0.88, 1.12)
const NORMAL_SCALE: Vector2 = Vector2(1.0, 1.0)

func _enter() -> void:
	if obj.is_on_floor():
		obj.change_animation("attack")
		# Ground throw: slight slowdown (feels deliberate, not frozen)
		# Ranged should reward positioning, not punish with full stop
		if not obj._is_on_ice():
			obj.velocity.x *= GROUND_THROW_MOMENTUM_KEEP
		# Ice: keep full momentum (slippery throw!)
	else:
		obj.change_animation("Jump_attack")
		# Air throw: preserve FULL momentum (throw while moving!)
		# Ranged fantasy: safe option that rewards mobility
	
	timer = obj.throw_duration
	
	# Throw release feedback — windup and release squash/stretch
	_apply_throw_feedback()
	
	obj.throw_blade_projectile()

func _exit() -> void:
	# Cleanup scale tween to prevent conflicts
	_cleanup_scale_tween()


func _update(delta: float) -> void:
	if update_timer(delta):
		change_state(fsm.previous_state)


## Throw windup-release squash/stretch — satisfying ranged feel
func _apply_throw_feedback() -> void:
	var direction_node = obj.get_node_or_null("Direction")
	if not direction_node:
		return
	
	var tween = _create_scale_tween()
	# Quick windup (pull back)
	tween.tween_property(direction_node, "scale", THROW_WINDUP, 0.03)
	# Snap to release (thrust forward)
	tween.tween_property(direction_node, "scale", THROW_RELEASE, 0.05)
	# Settle back
	tween.tween_property(direction_node, "scale", NORMAL_SCALE, 0.1).set_ease(Tween.EASE_OUT)
