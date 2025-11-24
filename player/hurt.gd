extends Player_State

func _enter():
	if obj.Effect["Invicibility"] > 0:
		change_state(fsm.previous_state)
	obj.change_animation("hurt")
	obj.velocity.y = -obj.hurt_knockback_vertical
	obj.velocity.x = 0
	timer = obj.hurt_stun_duration
	obj.invincible_timer = obj.max_invincible


func _update( delta: float):
	if update_timer(delta):
		change_state(fsm.states.idle)

func take_damage(damage:int):
	pass
