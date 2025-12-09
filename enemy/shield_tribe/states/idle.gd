extends EnemyState

func _enter() -> void:
	obj.change_animation("idle")
	obj.hide_shield()
	obj.velocity.x = 0  # Reset horizontal movement (stationary guard)

func _update(_delta: float) -> void:
	# Keep stationary by zeroing horizontal velocity
	obj.velocity.x = 0
	
	# Continuously check for player presence (not just on Area2D boundary crossing!)
	if obj.found_player:
		# Elite Warden: Check if should teleport or defend
		if obj.has_method("should_trigger_teleport") and obj.should_trigger_teleport():
			if fsm.states.has("teleport"):
				change_state(fsm.states.teleport)
				return
		
		# All Shield Tribe: Check if player is close enough to defend/attack
		var dist = obj.global_position.distance_to(obj.found_player.global_position)
		var detection_threshold = obj.attack_detection_radius if "attack_detection_radius" in obj else 105.0
		# Account for player collision buffer (Area2D triggers ~15px early)
		var buffer = obj.PLAYER_COLLISION_BUFFER if "PLAYER_COLLISION_BUFFER" in obj else 15.0
		
		if dist <= (detection_threshold + buffer):
			# Player close enough - switch to defend
			if fsm.states.has("defend"):
				change_state(fsm.states.defend)
