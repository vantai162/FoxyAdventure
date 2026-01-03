extends Player_State

## Jump launch dust effect — organic feedback for takeoff
## Uses hand-drawn smoke assets for better visual feel
const JUMP_DUST: PackedScene = preload("res://assets/effects/dust_puff.tscn")
const SMOKE_PUFF: PackedScene = preload("res://assets/effects/smoke_puff.tscn")

## Squash and stretch scales — adds life to movement
## NOTE: These are Y-only to preserve X direction sign!
const JUMP_STRETCH_Y: float = 1.2  ## Vertical stretch on jump
const JUMP_SQUASH_X: float = 0.85  ## Horizontal squash (applied with sign preservation)

func _enter() -> void:
	obj.change_animation("jump")
	super._enter()
	AudioManager.play_sound("player_jump",20.0)
	
	# Squash and stretch: vertical stretch on takeoff
	_apply_jump_stretch()
	
	# Spawn jump dust based on WHERE we jumped FROM
	# CRITICAL: Can't use is_on_floor() here - player already left ground!
	if fsm.previous_state == fsm.states.wallcling:
		# Wall jump: smoke shoots FROM wall, away from player
		obj.wall_jump_restriction_timer = 0.0
		_spawn_wall_jump_dust()
	elif fsm.previous_state == fsm.states.idle or fsm.previous_state == fsm.states.run:
		# Ground jump: smoke shoots UP from where feet pushed off
		obj.wall_jump_restriction_timer = -1.0
		_spawn_jump_dust()
	else:
		# Coyote jump or other edge case
		obj.wall_jump_restriction_timer = -1.0

func _exit() -> void:
	# Cleanup scale tween to prevent conflicts with next state
	_cleanup_scale_tween()

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
## Uses both particle effect AND hand-drawn smoke for layered feel
func _spawn_jump_dust() -> void:
	# Particle dust (subtle, fast)
	var dust = JUMP_DUST.instantiate()
	dust.global_position = obj.global_position + Vector2(0, 14)
	dust.emitting = true
	get_tree().current_scene.add_child(dust)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(dust):
			dust.queue_free()
	)
	
	# Hand-drawn smoke puff (prominent, animated)
	var smoke = SMOKE_PUFF.instantiate()
	smoke.global_position = obj.global_position + Vector2(0, 10)
	smoke.scale = Vector2(0.6, 0.6)  ## Scale down for jump — not too big
	get_tree().current_scene.add_child(smoke)

## Spawn dust when pushing off wall — directional puff
## Smoke spawns AT the wall and shoots AWAY from it (toward player's jump direction)
func _spawn_wall_jump_dust() -> void:
	# Player jumped in obj.direction, wall is behind them
	
	# Particle dust at wall (behind player)
	var dust = JUMP_DUST.instantiate()
	dust.global_position = obj.global_position + Vector2(-obj.direction * 12, 0)
	dust.emitting = true
	get_tree().current_scene.add_child(dust)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(dust):
			dust.queue_free()
	)
	
	# Smoke at wall, shooting AWAY from wall (in player's jump direction)
	var smoke = SMOKE_PUFF.instantiate()
	smoke.global_position = obj.global_position + Vector2(-obj.direction * 14, 0)
	smoke.scale = Vector2(0.6, 0.6)
	# Asset shoots UP. Rotate to shoot horizontally AWAY from wall:
	# direction=1 (jumped right, wall on left): rotate +90° to shoot RIGHT
	# direction=-1 (jumped left, wall on right): rotate -90° to shoot LEFT
	smoke.rotation_degrees = 90.0 * obj.direction
	get_tree().current_scene.add_child(smoke)

## Squash and stretch — vertical stretch on jump for springy feel
## CRITICAL: Preserve X sign for direction!
func _apply_jump_stretch() -> void:
	var direction_node = obj.get_node_or_null("Direction")
	if not direction_node:
		return
	# Instant stretch (preserving facing)
	var facing = sign(direction_node.scale.x) if direction_node.scale.x != 0 else 1.0
	direction_node.scale = Vector2(facing * JUMP_SQUASH_X, JUMP_STRETCH_Y)
	# Animate ONLY Y — let direction system handle X
	var tween = _create_scale_tween()
	tween.tween_property(direction_node, "scale:y", 1.0, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_callback(func():
		if direction_node:
			var current_facing = sign(direction_node.scale.x) if direction_node.scale.x != 0 else 1.0
			direction_node.scale.x = current_facing * 1.0
	)
