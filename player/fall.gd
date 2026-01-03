extends Player_State

## Landing dust effect — organic feedback for impact
## Uses hand-drawn smoke assets for better visual feel
const LANDING_DUST: PackedScene = preload("res://assets/effects/dust_puff.tscn")
const SMOKE_PUFF: PackedScene = preload("res://assets/effects/smoke_puff.tscn")

## Squash and stretch constants — horizontal squash on landing
## NOTE: Values only, direction preserved at runtime
const LANDING_SQUASH_X: float = 1.2  ## Wide
const LANDING_SQUASH_Y: float = 0.8  ## Short

var was_airborne: bool = false  ## Track if we were in the air (for landing detection)

func _enter() -> void:
	obj.change_animation("fall")
	was_airborne = true

func _update(_delta: float) -> void:
	var is_moving = false
	var jumped = false
	
	# Coyote jump: allow jump briefly after leaving ground
	# CRITICAL: Only call control_jump ONCE per frame to prevent race conditions
	if obj._checkcoyotea():
		jumped = control_jump()
	
	# Control moving
	if obj.Effect["Stun"] <= 0:
		is_moving = control_moving()
		control_throw()
		control_attack()
		# Only call jump if coyote didn't already handle it
		if not jumped:
			control_jump()
		control_dash()
	# Note: When stunned, control_moving() is not called, so velocity persists
	# This allows stunned player to slide on ice naturally
	
	# Landing detection — spawn dust on impact
	if obj.is_on_floor() and was_airborne:
		was_airborne = false
		_spawn_landing_dust()
		_apply_landing_squash()
	
	# If on floor change to idle if not moving and not jumping
	if obj.is_on_floor() and not is_moving:
		change_state(fsm.states.idle)
	if obj.is_on_floor():
		obj.jump_count = 0
		obj.dashed_on_air = false
	# Wall cling: only if not on ice wall AND player is actively pressing toward wall
	# This implements "active" wall cling - no input = just fall past the wall
	if obj.is_on_wall_only() and not obj._is_wall_ice():
		if not obj.wall_cling_requires_input or obj.is_pressing_toward_wall():
			fsm.change_state(fsm.states.wallcling)
	if obj.is_in_water and obj.is_head_underwater():
		fsm.change_state(fsm.states.swim)

## Spawn dust puff on landing — visual weight and impact
## Uses both particle effect AND hand-drawn smoke for layered feel
func _spawn_landing_dust() -> void:
	# Particle dust (subtle, fast)
	var dust = LANDING_DUST.instantiate()
	dust.global_position = obj.global_position + Vector2(0, 14)
	dust.emitting = true
	get_tree().current_scene.add_child(dust)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(dust):
			dust.queue_free()
	)
	
	# Hand-drawn smoke puff (prominent, animated)
	var smoke = SMOKE_PUFF.instantiate()
	smoke.global_position = obj.global_position + Vector2(0, 12)
	smoke.scale = Vector2(0.7, 0.7)  ## Landing is bigger impact than jump
	get_tree().current_scene.add_child(smoke)

## Squash and stretch — horizontal squash on landing for weight
## CRITICAL: Preserve X sign for direction!
func _apply_landing_squash() -> void:
	var direction_node = obj.get_node_or_null("Direction")
	if not direction_node:
		return
	var facing = sign(direction_node.scale.x) if direction_node.scale.x != 0 else 1.0
	direction_node.scale = Vector2(facing * LANDING_SQUASH_X, LANDING_SQUASH_Y)
	var tween = _create_scale_tween()
	tween.tween_property(direction_node, "scale", Vector2(facing * 1.0, 1.0), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
