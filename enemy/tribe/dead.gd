extends EnemyState


func _enter():
	obj.change_animation("dead")
	obj.velocity.x = 0
	obj.get_node("Direction/HurtArea2D/CollisionShape2D").disabled = true
	await get_tree().create_timer(1.0).timeout
	obj.queue_free()

		
