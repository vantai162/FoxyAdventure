extends Player_State

## Double Jump State — Full air control like regular jump
## FIXED: Was missing control_throw, control_attack, control_dash

## Air burst effect for double jump — distinct from ground jump
const AIR_BURST_DUST: PackedScene = preload("res://assets/effects/dust_puff.tscn")

## Squash/stretch for double jump — MORE DRAMATIC than ground jump for visibility
## The double jump is a magical air push, so exaggerate it!
const DOUBLE_JUMP_STRETCH_Y: float = 1.25  ## Taller stretch (was 1.15)
const DOUBLE_JUMP_SQUASH_X: float = 0.75   ## Wider squash (was 0.9)

func _enter() -> void:
	# Double jump doesn't restrict air control - uses base air_control_base
	obj.wall_jump_restriction_timer = -1.0  # Ensure no restriction active
	# Use "fall" animation - the ascending "fall" frame looks like air pushing up
	# This distinguishes from ground "jump" and makes double jump feel floatier
	obj.change_animation("fall")
	_spawn_air_burst()
	_apply_double_jump_stretch()

func _exit() -> void:
	# Cleanup scale tween to prevent conflicts
	_cleanup_scale_tween()

func _update(delta: float) -> void:
	if obj.Effect["Stun"] <= 0:
		control_moving()
		control_throw()
		control_attack()
		control_jump()  # Allows wall jump if player touches wall
		control_dash()
	# Note: When stunned, control_moving() is not called, so velocity persists
	
	if obj.velocity.y > 0:
		change_state(fsm.states.fall)
	
	# Wall cling: only if not on ice wall AND player is actively pressing toward wall
	if obj.is_on_wall_only() and not obj._is_wall_ice():
		if not obj.wall_cling_requires_input or obj.is_pressing_toward_wall():
			change_state(fsm.states.wallcling)

## Spawn air burst at feet — magical mid-air push
func _spawn_air_burst() -> void:
	var dust = AIR_BURST_DUST.instantiate()
	# Spawn at current position (mid-air)
	dust.global_position = obj.global_position + Vector2(0, 8)
	dust.emitting = true
	get_tree().current_scene.add_child(dust)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(dust):
			dust.queue_free()
	)

## Squash/stretch for double jump — lighter than ground jump
## CRITICAL: Only animate Y to avoid direction race condition!
func _apply_double_jump_stretch() -> void:
	var direction_node = obj.get_node_or_null("Direction")
	if not direction_node:
		return
	var facing = sign(direction_node.scale.x) if direction_node.scale.x != 0 else 1.0
	direction_node.scale = Vector2(facing * DOUBLE_JUMP_SQUASH_X, DOUBLE_JUMP_STRETCH_Y)
	var tween = _create_scale_tween()
	tween.tween_property(direction_node, "scale:y", 1.0, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_callback(func():
		if direction_node:
			var current_facing = sign(direction_node.scale.x) if direction_node.scale.x != 0 else 1.0
			direction_node.scale.x = current_facing * 1.0
	)
