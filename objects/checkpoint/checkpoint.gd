extends Area2D
class_name Checkpoint


## Checkpoint that saves player progress when activated
## Now with satisfying activation feedback!


#signal when checkpoint is activated
signal checkpoint_activated(checkpoint_id: String)


@export var checkpoint_id: String = ""


var is_activated: bool = false


func _ready() -> void:
	if checkpoint_id.is_empty():
		checkpoint_id = str(get_path())
	$AnimatedSprite2D.play("idle")
	if GameManager.current_checkpoint_id == checkpoint_id:
		activate_visual_only()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		activate()



func activate() -> void:
	print("ĐÃ CHẠM VÀ KÍCH HOẠT CHECKPOINT!")
	if is_activated:
		return
	is_activated = true
	$AnimatedSprite2D.play("active")
	GameManager.player.heal_max_health()
	AudioManager.play_sound("heal",20.0)
	GameManager.save_checkpoint(checkpoint_id)
	GameManager.save_checkpoint_data()
	checkpoint_activated.emit(checkpoint_id)
	
	# Activation feedback — satisfying visual burst
	_spawn_activation_feedback()
	
	await get_tree().create_timer(1.0).timeout

	$AnimatedSprite2D.play("idle")


#activate checkpoint visually without saving
func activate_visual_only() -> void:
	$AnimatedSprite2D.play("active")
	# No need to set is_activated here, as it's only visual


## Spawn satisfying activation burst — sparkles and glow pulse
func _spawn_activation_feedback() -> void:
	# Create activation particles
	var particles = GPUParticles2D.new()
	particles.amount = 8
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.one_shot = true
	particles.z_index = 5
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, -10, 0)  # Float up
	mat.scale_min = 0.8
	mat.scale_max = 1.2
	mat.color = Color(0.4, 1.0, 0.5, 1.0)  # Green/heal color
	particles.process_material = mat
	
	# 4x4 texture per doctrine
	var grad = Gradient.new()
	grad.set_color(0, Color(0.6, 1.0, 0.7, 1.0))
	grad.set_color(1, Color(0.4, 1.0, 0.5, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 4
	tex.height = 4
	particles.texture = tex
	
	add_child(particles)
	particles.emitting = true
	
	# Cleanup
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
	
