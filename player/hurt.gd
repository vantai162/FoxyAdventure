extends Player_State

func _enter():
	obj.change_animation("hurt")
	obj.health_changed.emit()
	obj.velocity.y = -obj.hurt_knockback_vertical
	obj.velocity.x = 0
	timer = obj.hurt_stun_duration
	#obj.invincible_timer=obj.max_invincible chuyen invible sang ham takedam chuyen sang dung invicible sang dang effect


func _update( delta: float):
	if update_timer(delta):
		change_state(fsm.states.idle)

func take_damage(damage:int):
	obj.take_damage(damage)
