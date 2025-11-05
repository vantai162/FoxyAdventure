extends EnemyState

@export var toxic_gas_scene: PackedScene

func _enter() -> void:
	obj.change_animation("surprise")
	await get_tree().create_timer(0.5).timeout  
	_spawn_toxic_gas()
	obj.queue_free()

func _spawn_toxic_gas():
	if toxic_gas_scene == null:
		push_warning("toxic_gas_scene chưa được gán!")
		return
	
	var gas = toxic_gas_scene.instantiate()
	gas.global_position = obj.global_position
	obj.get_parent().add_child(gas)
