extends EnemyState


func _enter():
	print("daed")
	obj.change_animation("dead")
	timer = 1.0
	obj.velocity.x = 0

func _update(delta):
	if update_timer(delta):
		obj.queue_free()
