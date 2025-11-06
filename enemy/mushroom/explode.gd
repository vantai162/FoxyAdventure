extends EnemyState

@export var toxic_gas_scene: PackedScene
@export var gas_speed: float = 60.0
func _enter() -> void:
	obj.change_animation("explode")
	obj.velocity.x = 0
	await get_tree().create_timer(1.5).timeout  
	_spawn_toxic_gas()
	obj.queue_free()

func _spawn_toxic_gas():
	if toxic_gas_scene == null:
		push_warning("toxic_gas_scene chưa được gán!")
		return  

	for dir in [-1, 1]:
		var gas = toxic_gas_scene.instantiate()
		gas.global_position = obj.global_position
		gas.velocity = Vector2(gas_speed * dir, randf_range(-20, 20)) 
		obj.get_parent().add_child(gas)
