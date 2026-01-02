extends Player_State

## Jump launch dust effect — organic feedback for takeoff
const JUMP_DUST: PackedScene = preload("res://assets/effects/dust_puff.tscn")

## Squash and stretch scales — adds life to movement
const JUMP_STRETCH: Vector2 = Vector2(0.85, 1.2)  ## Vertical stretch on jump
const NORMAL_SCALE: Vector2 = Vector2(1.0, 1.0)

func _enter() -> void:
	obj.change_animation("jump")
	super._enter()
	AudioManager.play_sound("player_jump",20.0)
	
	# Squash and stretch: vertical stretch on takeoff
	_apply_jump_stretch()
	
	# Spawn jump dust if jumping from floor (not wall jump)
	if fsm.previous_state != fsm.states.wallcling and obj.is_on_floor():
		_spawn_jump_dust()
	
	# If coming from wall cling, activate wall jump air restriction
	if fsm.previous_state == fsm.states.wallcling:
		obj.wall_jump_restriction_timer = 0.0
		_spawn_wall_jump_dust()
	else:
		obj.wall_jump_restriction_timer = -1.0  # Normal jump: no restriction

func _exit() -> void:
	# Timer naturally expires or gets reset by next jump
	pass

func _update(delta: float):
	# Update wall jump restriction timer if active
	if obj.wall_jump_restriction_timer >= 0:
		obj.wall_jump_restriction_timer += delta
	
	if obj.Effect["Stun"] <= 0:
		# Wall jump control delay: restrict control_moving during initial frames
		var can_control = obj.wall_jump_restriction_timer < 0 or \
						  obj.wall_jump_restriction_timer >= obj.wall_jump_control_delay
		
		if can_control:
			control_moving()
		
		control_throw()
		control_attack()
		control_jump()
		control_dash()
	# Note: When stunned, control_moving() is not called, so velocity persists
	# This allows stunned player to maintain jump arc naturally
	
	if obj.velocity.y > 0:
		change_state(fsm.states.fall)
	# Wall cling: only if not on ice wall AND player is actively pressing toward wall
	# This implements "active" wall cling - no input = just fall past the wall
	if obj.is_on_wall_only() and not obj._is_wall_ice():
		if not obj.wall_cling_requires_input or obj.is_pressing_toward_wall():
			change_state(fsm.states.wallcling)

## Spawn dust puff on jump — visual oomph for takeoff
func _spawn_jump_dust() -> void:
	var dust = JUMP_DUST.instantiate()
	# Feet position at y ≈ +14 below origin
	dust.global_position = obj.global_position + Vector2(0, 14)
	dust.emitting = true
	get_tree().current_scene.add_child(dust)
	# Auto-cleanup
	get_tree().create_timer(0.6).timeout.connect(dust.queue_free)

## Spawn dust when pushing off wall — directional puff
func _spawn_wall_jump_dust() -> void:
	var dust = JUMP_DUST.instantiate()
	# Dust spawns at wall contact point, opposite of jump direction
	dust.global_position = obj.global_position + Vector2(-obj.direction * 8, 0)
	dust.emitting = true
	get_tree().current_scene.add_child(dust)
	# Auto-cleanup
	get_tree().create_timer(0.6).timeout.connect(dust.queue_free)

## Squash and stretch — vertical stretch on jump for springy feel
func _apply_jump_stretch() -> void:
	var direction_node = obj.get_node_or_null("Direction")
	if not direction_node:
		return
	# Snap to stretch, then tween back to normal
	direction_node.scale = JUMP_STRETCH
	var tween = create_tween()
	tween.tween_property(direction_node, "scale", NORMAL_SCALE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
