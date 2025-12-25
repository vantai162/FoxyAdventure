extends "res://enemy/aggressive_tribe/states/attack.gd"
class_name EliteAttackState
## Elite Attack State: ALL slowing coconuts for overwhelming zone control
## Creates puddle minefield, forces player into mobility penalty hell

func _throw_next_coconut() -> void:
	throw_count += 1
	
	# ELITE BEHAVIOR: ALL throws are slowing coconuts (overwhelming zone control)
	var coconut_scene = obj.special_coconut_scene
	if not coconut_scene:
		push_warning("EliteAttack: special_coconut_scene not assigned! Elite needs slowing coconuts.")
		return
	
	# Calculate ballistic trajectory with physics (inherited from base)
	var launch_velocity = _calculate_ballistic_throw()
	obj.throw_coconut(coconut_scene, obj.throw_origin.global_position, launch_velocity)
	AudioManager.play_sound("warlord_bomb_launch",18.0)
	# Burst completion logic
	if throw_count >= 3:
		# Attack complete, return to run (or pursue for elite)
		if obj.found_player:
			obj.attack_timer.start()
		
		# Elite returns to pursue if player still exists
		if fsm.states.has("pursue") and obj.found_player:
			change_state(fsm.states.pursue)
		else:
			change_state(fsm.states.run)
	else:
		obj.throw_timer.start()
