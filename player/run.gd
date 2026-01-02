extends Player_State

## "Light feet" dust effect — communicates dash readiness organically
## No UI needed: visible dust puffs = dash available, no dust = cooling down
const DASH_READY_DUST: PackedScene = preload("res://assets/effects/dash_ready_dust.tscn")

var waited: float = 0.0
var dust_timer: float = 0.0
var dust_interval: float = 0.18  ## Time between dust puffs when dash ready

func _enter() -> void:
	super._enter()
	waited = 0.0
	dust_timer = 0.0
	obj.change_animation("run")

func _update(delta: float):
	obj.current_oxygen = min(obj.max_oxygen, obj.current_oxygen + obj.oxygen_increase_rate * delta)

	if control_jump():
		return

	control_throw()
	control_attack()

	if not control_moving():
		waited += delta
		if waited > obj.run_idle_wait_time:
			change_state(fsm.states.idle)
	else:
		# "Light feet" visual feedback — dust puffs when dash is available
		if obj.CoolDown["Dash"] <= 0 and obj.is_on_floor():
			dust_timer += delta
			if dust_timer >= dust_interval:
				dust_timer = 0.0
				_spawn_foot_dust()
		
		if control_dash():
			return
		# tăng speed khi nhấn lại
		if obj.run_idle_wait_time > waited and obj.direction > 0 and Input.is_action_just_pressed("right"):
			obj.current_speed = obj.runspeed
		elif obj.run_idle_wait_time > waited and obj.direction < 0 and Input.is_action_just_pressed("left"):
			obj.current_speed = obj.runspeed

	if not obj.is_on_floor():
		change_state(fsm.states.fall)
	# Wall cling: only if not on ice wall AND player is actively pressing toward wall
	# This implements "active" wall cling - no input = just fall past the wall
	if obj.is_on_wall_only() and not obj._is_wall_ice():
		if not obj.wall_cling_requires_input or obj.is_pressing_toward_wall():
			change_state(fsm.states.wallcling)
	if obj.is_in_water and obj.is_head_underwater():
		change_state(fsm.states.swim)

## Spawn subtle dust puff at player's feet — "light feet" = dash ready
func _spawn_foot_dust() -> void:
	var dust = DASH_READY_DUST.instantiate()
	# Feet position: player origin (0,0) is center-ish, feet are at bottom
	# Collision is 21x30 at (-0.5, -1), so feet are at y ≈ +14
	dust.global_position = obj.global_position + Vector2(-obj.direction * 4, 14)
	dust.emitting = true
	get_tree().current_scene.add_child(dust)
	# Auto-cleanup after particles finish
	get_tree().create_timer(0.5).timeout.connect(dust.queue_free)
