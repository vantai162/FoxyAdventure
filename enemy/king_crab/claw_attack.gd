extends EnemyState

# Phase 2: Claw wrap-around attack

var claw_spawned: bool = false

func _enter() -> void:
	obj.change_animation("claw_attack")
	obj.velocity = Vector2.ZERO
	claw_spawned = false
	
	# Spawn claw after animation windup
	get_tree().create_timer(0.5).timeout.connect(_spawn_claw)

func _spawn_claw() -> void:
	if fsm.current_state != self:
		return
	
	if obj.claw_factory and obj.claw_factory.has_method("create"):
		var claw = obj.claw_factory.create()
		if claw and obj.found_player:
			# Claw targets player's current position
			claw.target_position = obj.found_player.global_position
	
	claw_spawned = true
	
	# Return to idle after attack
	get_tree().create_timer(1.5).timeout.connect(_finish_attack)

func _finish_attack() -> void:
	if fsm.current_state != self:
		return
	change_state(fsm.states.idle)

func _update(delta: float) -> void:
	pass
