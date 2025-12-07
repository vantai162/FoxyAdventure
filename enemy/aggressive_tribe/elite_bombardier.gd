extends AggressiveTribe
class_name EliteBombardier
## Elite Aggressive Tribe: "The Bombardier"
## ALL coconuts are slowing coconuts - overwhelming zone control
## Timing-based difficulty: faster bursts, shorter cooldowns
## ACTIVELY PURSUES player - not passive turret

func _ready() -> void:
	super._ready()
	
	# Verify slowing coconut is assigned
	if not special_coconut_scene:
		push_warning("EliteBombardier: special_coconut_scene not set! Assign SlowingCoconut scene.")
	
	# Elite timing tuning (configure in scene exports):
	# - burst_cooldown: 1.8 (base is 2.0) - throws more often
	# - burst_throw_interval: 0.2 (base is 0.25) - faster burst
	# - throw_force: 380 (base is 350) - slightly more range
	# Natural pressure through timing alone - no code complexity

# Override to use pursue state instead of passive patrol
func _on_player_in_sight(_player_pos: Vector2) -> void:
	if found_player:
		if found_player.global_position.x > global_position.x:
			change_direction(1)
		else:
			change_direction(-1)
	
	# Elite behavior: Pursue player aggressively
	if fsm.current_state == fsm.states.run:
		if fsm.states.has("pursue"):
			fsm.change_state(fsm.states.pursue)
		else:
			# Fallback to base behavior if pursue state missing
			if attack_timer.is_stopped():
				_on_attack_timer_timeout()

func _on_player_not_in_sight() -> void:
	# Return to patrol when player lost
	if fsm.current_state == fsm.states.pursue:
		fsm.change_state(fsm.states.run)
	# Also handle attack state (base behavior)
	elif fsm.current_state == fsm.states.attack or fsm.current_state == fsm.states.windup:
		attack_timer.stop()
		fsm.change_state(fsm.states.run)
