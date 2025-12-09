extends Player_State

## Throw momentum preservation multiplier for ground throws
## 1.0 = full momentum, 0.5 = half speed, 0.0 = full stop
const GROUND_THROW_MOMENTUM_KEEP: float = 0.6

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
	obj.throw_blade_projectile()

func _exit() -> void:
	pass

func _update(delta: float) -> void:
	if update_timer(delta):
		change_state(fsm.previous_state)
