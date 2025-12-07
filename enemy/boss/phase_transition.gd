extends EnemyState

## Phase transition state - dramatic pause before entering phase 2
## Plays enrage animation and makes boss briefly invincible

var has_started_enrage: bool = false

func _enter() -> void:
	# Stop all movement
	obj.velocity = Vector2.ZERO
	
	# Make boss invincible during transition
	obj.invincible = true
	
	has_started_enrage = false
	timer = obj.phase_transition_roar_delay
	
	# Initial animation (hurt/stagger from the hit that triggered phase 2)
	obj.change_animation("hurt")


func _update(delta: float) -> void:
	if not has_started_enrage:
		if update_timer(delta):
			AudioManager.play_sound("warlord_roar",20.0)
			# Start enrage animation (use skill2 as "roar" visual)
			has_started_enrage = true
			obj.change_animation("skill2")
			timer = obj.phase_transition_pause
			
			
	else:
		if update_timer(delta):
			# Transition complete - enter phase 2
			obj.current_phase = 2
			obj.invincible = false
			obj.invincible_timer = obj.max_invincible  # Brief invincibility after transition
			print("PHASE 2 ACTIVATED")
			change_state(fsm.states.idle)


func _exit() -> void:
	obj.invincible = false
