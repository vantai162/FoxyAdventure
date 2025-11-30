extends EnemyState

func _enter():
	print("alo")
	obj.change_animation("vulnerable")
	obj.get_node("Direction/HurtArea2D/CollisionShape2D").disabled = true
	obj.velocity.x = 0

func _process(delta: float) -> void:
	pass
