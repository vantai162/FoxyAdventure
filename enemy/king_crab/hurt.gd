
extends EnemyState

## King Crab Boss Hurt State — LEGACY (stun_immune = true means this rarely runs)
## With poise system in enemy_state.gd, bosses skip this state during normal combat.
## This state is kept for:
## - Death transition
## - Fallback if stun_immune is ever disabled
## - Animation purposes if manually triggered

func _enter():
	obj.change_animation("hurt")
	timer = 0.1  # Minimal time — boss recovers fast

func _update(delta: float):
	if update_timer(delta):
		if obj.health <= 0:
			change_state(fsm.states.dead)
		else:
			change_state(fsm.states.idle)

## NOTE: This take_damage override is LEGACY
## With stun_immune = true, EnemyState.take_damage() never calls change_state(hurt)
## Damage is handled directly via king_crab.take_damage() override
