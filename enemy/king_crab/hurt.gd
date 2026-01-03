
extends EnemyState

## King Crab Boss Hurt State — POISE ENABLED
## Boss does NOT get knocked back. Boss does NOT get stun-locked.
## This is a VISUAL FEEDBACK state only — returns to idle almost instantly.

func _enter():
	## Flash effect is handled in king_crab.take_damage() override
	## This state exists only for death check transition
	obj.change_animation("hurt")
	timer = 0.1  # Minimal time — boss recovers fast

func _update(delta: float):
	if update_timer(delta):
		if obj.health <= 0:
			change_state(fsm.states.dead)
		else:
			change_state(fsm.states.idle)

## POISE OVERRIDE: Boss takes damage but is NOT knocked back
func take_damage(_damage_dir: Vector2, damage: int) -> void:
	## CRITICAL: Do NOT apply knockback to boss
	## obj.velocity.x = _damage_dir.x * obj.knockback_force  ← REMOVED
	
	# Apply damage through proper system (handles flash, phase transitions)
	obj.take_damage(damage)
	
	# Do NOT change state — boss continues current attack
	# The visual flash is handled by king_crab.take_damage()
