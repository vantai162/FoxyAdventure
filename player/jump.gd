extends Player_State

var stored_air_control: float = 1.0
var wall_jump_timer: float = 0.0

func _enter() -> void:
	obj.change_animation("jump")
	if fsm.previous_state == fsm.states.wallcling:
		stored_air_control = obj.air_control if "air_control" in obj else 1.0
		wall_jump_timer = 0.0
		obj.air_control = obj.wall_jump_air_control
	else:
		obj.air_control = 1.0
		wall_jump_timer = -1.0

func _exit() -> void:
	if wall_jump_timer >= 0:
		obj.air_control = stored_air_control

func _update(delta: float):
	if wall_jump_timer >= 0:
		wall_jump_timer += delta
		if wall_jump_timer >= obj.wall_jump_control_fade_duration:
			obj.air_control = stored_air_control
			wall_jump_timer = -1.0
		else:
			var blend = wall_jump_timer / obj.wall_jump_control_fade_duration
			obj.air_control = lerp(obj.wall_jump_air_control, stored_air_control, blend)
	
	if obj.Effect["Stun"] <= 0:
		if wall_jump_timer < 0 or wall_jump_timer >= obj.wall_jump_control_delay:
			control_moving()
		control_throw()
		control_attack()
		control_jump()
		control_dash()
	else:
		obj.velocity.x = 0
	
	if obj.velocity.y > 0:
		change_state(fsm.states.fall)
	if obj.is_on_wall_only():
		change_state(fsm.states.wallcling)
