extends EnemyState

# King Crab Idle - Choose next action
var idle_time: float = 0.0
var next_action_delay: float = 1.5

func _enter() -> void:
	obj.change_animation("idle")
	obj.velocity = Vector2.ZERO
	idle_time = 0.0

func _update(delta: float) -> void:
	idle_time += delta
	
	if idle_time < next_action_delay:
		return
	
	# Phase 2: Add roll bounce to rotation
	if obj.current_phase == 2 and obj.found_player and randf() < 0.3:
		change_state(fsm.states.roll_bounce)
		return
	
	# Decision tree: coconut throw > dive > claw
	if obj.can_throw_coconut and obj.found_player:
		obj.target_tree = obj.find_nearest_tree()
		if obj.target_tree:
			change_state(fsm.states.walk_to_tree)
			return
	
	if obj.can_dive and obj.found_player:
		change_state(fsm.states.dive_attack)
		return
	
	if obj.can_claw and obj.found_player and obj.current_phase == 2:
		change_state(fsm.states.claw_attack)
		return
	
	# No action available, wait longer
	idle_time = 0.0
