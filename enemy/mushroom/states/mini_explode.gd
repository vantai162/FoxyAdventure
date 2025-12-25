extends EnemyState
## Mini mushroom explosion state
## Faster explosion (1.0s vs 1.5s), spawns single gas cloud (not 2)

@export var toxic_gas_scene: PackedScene  ## DEPRECATED: Use ToxicGasFactory instead
@export var gas_speed: float = 80.0  ## Faster spread than base (60)

func _enter() -> void:
	obj.change_animation("explode")
	obj.velocity.x = 0
	
	# Disable hurt area during explosion
	if obj.has_node("Direction/HurtArea2D/CollisionShape2D"):
		obj.get_node("Direction/HurtArea2D/CollisionShape2D").disabled = true
	
	# Faster explosion timer (1.0s vs base 1.5s)
	await get_tree().create_timer(1.0).timeout
	_spawn_toxic_gas()
	AudioManager.play_sound("gas",15.0)
	obj.queue_free()

func _spawn_toxic_gas():
	var gas_factory = obj.get_node_or_null("Direction/ToxicGasFactory")
	if not gas_factory:
		push_warning("Mini Mushroom: ToxicGasFactory not found, falling back to manual spawn!")
		_spawn_toxic_gas_manual()
		return
	
	# Mini mushroom: Only 1 gas cloud (random direction) using factory
	var dir = 1 if randf() > 0.5 else -1
	
	var gas = gas_factory.create()
	gas.velocity = Vector2(gas_speed * dir, randf_range(-15, 15))
	gas.scale = Vector2(0.6, 0.6)  ## Mini gas cloud: Smaller scale

func _spawn_toxic_gas_manual():
	## DEPRECATED fallback for scenes not yet updated with factory
	if toxic_gas_scene == null:
		push_warning("MiniExplode: toxic_gas_scene not assigned!")
		return
	
	var dir = 1 if randf() > 0.5 else -1
	var gas = toxic_gas_scene.instantiate()
	gas.global_position = obj.global_position
	gas.velocity = Vector2(gas_speed * dir, randf_range(-15, 15))
	gas.scale = Vector2(0.6, 0.6)
	obj.get_parent().add_child(gas)
