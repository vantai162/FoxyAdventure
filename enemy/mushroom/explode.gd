extends EnemyState

@export var toxic_gas_scene: PackedScene  ## DEPRECATED: Use ToxicGasFactory instead
@export var gas_speed: float = 60.0

func _enter() -> void:
	obj.change_animation("explode")
	obj.velocity.x = 0
	obj.get_node("Direction/HurtArea2D/CollisionShape2D").disabled = true
	await get_tree().create_timer(1.5).timeout  
	_spawn_toxic_gas()
	AudioManager.play_sound("gas",10.0)
	obj.queue_free()

func _spawn_toxic_gas():
	var gas_factory = obj.get_node_or_null("Direction/ToxicGasFactory")
	if not gas_factory:
		push_warning("OG Mushroom: ToxicGasFactory not found, falling back to manual spawn!")
		_spawn_toxic_gas_manual()
		return
	
	# Spawn 2 gas clouds (left and right) using factory
	for dir in [-1, 1]:
		var gas = gas_factory.create()
		gas.velocity = Vector2(gas_speed * dir, randf_range(-5, 5))


func _spawn_toxic_gas_manual():
	## DEPRECATED fallback for scenes not yet updated with factory
	if toxic_gas_scene == null:
		push_warning("toxic_gas_scene chưa được gán!")
		return  

	for dir in [-1, 1]:
		var gas = toxic_gas_scene.instantiate()
		gas.global_position = obj.global_position
		gas.velocity = Vector2(gas_speed * dir, randf_range(-20, 20)) 
		obj.get_parent().add_child(gas)
