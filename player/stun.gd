extends Player_State

func _enter() -> void:
	obj.change_animation("stun")
	obj.stun_ani.visible = true
	obj.stun_ani.play("default")
	obj.velocity.x=0

func _update(delta: float) -> void:
	obj._updateeffect(delta)
	if obj.Effect["Stun"] <= 0:
		obj.stun_ani.visible = false
		change_state(fsm.states.idle)
