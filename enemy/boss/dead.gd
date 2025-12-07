
extends EnemyState


func _enter():
	obj.change_animation("dead")
	timer = 1.0

	obj.velocity.x = 0
	obj.get_node("Direction/HurtArea2D/CollisionShape2D").disabled = true
	obj.get_node("Direction/HitArea2D/CollisionShape2D").disabled = true

func _update(delta):
	if update_timer(delta):
		obj.queue_free()
