
extends EnemyState


func _enter():
	# Reset any visual state (rotation, modulate, etc.) for clean death
	obj.get_node("Direction").rotation_degrees = 0.0
	if obj.animated_sprite:
		obj.animated_sprite.modulate = Color.WHITE
	
	obj.change_animation("dead")
	timer = 1.0
	GameManager.add_kill()
	obj.velocity.x = 0
	obj.get_node("Direction/HurtArea2D/CollisionShape2D").disabled = true
	obj.get_node("Direction/HitArea2D/CollisionShape2D").disabled = true

func _update(delta):
	if update_timer(delta):
		obj.queue_free()
