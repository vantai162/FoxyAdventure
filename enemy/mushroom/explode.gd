extends EnemyState

@export var toxic_gas_scene: PackedScene  ## DEPRECATED: Use ToxicGasFactory instead
@export var gas_speed: float = 60.0

func _enter() -> void:
	obj.change_animation("explode")
	obj.velocity.x = 0
	obj.get_node("Direction/HurtArea2D/CollisionShape2D").disabled = true
	await get_tree().create_timer(1.5).timeout
	
	# Explosion feedback — camera shake and particles
	_apply_explosion_feedback()
	
	_spawn_toxic_gas()
	AudioManager.play_sound("gas",10.0)
	obj.queue_free()


## Explosion feedback — dramatic mushroom pop
func _apply_explosion_feedback() -> void:
	# Camera shake for nearby player
	var player = get_tree().get_first_node_in_group("player")
	if player and player.global_position.distance_to(obj.global_position) < 150:
		var camera = player.get_node_or_null("Camera2D")
		if camera and camera.has_method("shake"):
			camera.shake(4.0)
	
	# Spore burst particles
	_spawn_spore_burst()


## Spawn spore burst particles — mushroom explosion visual
func _spawn_spore_burst() -> void:
	var burst = GPUParticles2D.new()
	burst.amount = 16
	burst.lifetime = 0.7
	burst.explosiveness = 1.0
	burst.one_shot = true
	burst.z_index = 25
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 70.0
	mat.gravity = Vector3(0, -15, 0)  # Spores float up
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = Color(0.6, 0.8, 0.3, 0.9)  # Toxic green/yellow
	burst.process_material = mat
	
	# 4x4 spore texture
	var grad = Gradient.new()
	grad.set_color(0, Color(0.7, 0.9, 0.4, 1.0))
	grad.set_color(1, Color(0.4, 0.6, 0.2, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 4
	tex.height = 4
	burst.texture = tex
	
	burst.global_position = obj.global_position
	get_tree().current_scene.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)

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
