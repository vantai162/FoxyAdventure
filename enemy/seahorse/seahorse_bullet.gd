extends RigidBody2D

func _physics_process(_delta: float) -> void:
	if is_zero_approx(linear_velocity.x):
		queue_free()

func _on_hit_area_2d_hitted(_area: Variant) -> void:
	queue_free()

func _on_body_entered(_body: Node) -> void:
	queue_free()
