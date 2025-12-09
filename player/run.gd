extends Player_State

var waited: float = 0.0

func _enter() -> void:
	super._enter()
	waited = 0.0
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
		if control_dash():
			return
		# tăng speed khi nhấn lại
		if obj.run_idle_wait_time > waited and obj.direction > 0 and Input.is_action_just_pressed("right"):
			obj.current_speed = obj.runspeed
		elif obj.run_idle_wait_time > waited and obj.direction < 0 and Input.is_action_just_pressed("left"):
			obj.current_speed = obj.runspeed

	if not obj.is_on_floor():
		change_state(fsm.states.fall)
	if obj.is_on_wall_only():
		change_state(fsm.states.wallcling)
	if obj.is_in_water and obj.is_head_underwater():
		change_state(fsm.states.swim)
