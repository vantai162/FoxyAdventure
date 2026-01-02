extends Player_State

## Double Jump State — Full air control like regular jump
## FIXED: Was missing control_throw, control_attack, control_dash

## Air burst effect for double jump — distinct from ground jump
const AIR_BURST_DUST: PackedScene = preload("res://assets/effects/dust_puff.tscn")

## Squash/stretch for double jump (less pronounced than ground jump)
const DOUBLE_JUMP_STRETCH: Vector2 = Vector2(0.9, 1.15)
const NORMAL_SCALE: Vector2 = Vector2(1.0, 1.0)

func _enter() -> void:
	# Double jump doesn't restrict air control - uses base air_control_base
	obj.wall_jump_restriction_timer = -1.0  # Ensure no restriction active
	obj.change_animation("jump")
	_spawn_air_burst()
	_apply_double_jump_stretch()

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
	get_tree().create_timer(0.6).timeout.connect(dust.queue_free)

## Squash/stretch for double jump — lighter than ground jump
func _apply_double_jump_stretch() -> void:
	var direction_node = obj.get_node_or_null("Direction")
	if not direction_node:
		return
	direction_node.scale = DOUBLE_JUMP_STRETCH
	var tween = create_tween()
	tween.tween_property(direction_node, "scale", NORMAL_SCALE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
