extends Player_State

## Camera shake on hurt — visceral damage feedback
const HURT_SHAKE_AMOUNT: float = 5.0

func _enter():
	obj.change_animation("hurt")
	obj.health_changed.emit()
	obj.velocity.y = -obj.hurt_knockback_vertical
	obj.velocity.x = 0
	timer = obj.hurt_stun_duration
	_apply_hurt_feedback()
	#obj.invincible_timer=obj.max_invincible chuyen invible sang ham takedam chuyen sang dung invicible sang dang effect

## Apply hit feedback — camera shake for damage impact
func _apply_hurt_feedback() -> void:
	var camera = obj.get_node_or_null("Camera2D")
	if camera and camera.has_method("shake"):
		camera.shake(HURT_SHAKE_AMOUNT)

func _update( delta: float):
	if update_timer(delta):
		change_state(fsm.states.idle)

func take_damage(damage:int):
	obj.take_damage(damage)
