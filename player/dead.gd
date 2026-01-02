extends Player_State

## Death screen flash color
const DEATH_FLASH_COLOR: Color = Color(0.8, 0.1, 0.1, 0.4)

func _enter() -> void:
	super._enter()
	obj.velocity = Vector2.ZERO
	obj.change_animation("dead")
	
	# Death feedback — dramatic camera shake and particles
	_apply_death_feedback()
	
	# Extinguish torch when player dies (no re-ignition - player is dead!)
	var torch = obj.get_node_or_null("Direction/PlayerTorch")
	if torch and torch.is_lit:
		torch.extinguish("death")
	
	AudioManager.play_sound("game_over",15.0)
	await obj.animated_sprite.animation_finished
	
	# Guard: check tree is still valid after await
	var tree = get_tree()
	if tree == null:
		return
	
	await tree.create_timer(obj.dead_delay_before_respawn).timeout
	
	# Guard again after another await
	if not is_instance_valid(obj) or get_tree() == null:
		return
	
	if GameManager.has_checkpoint():
		await GameManager.respawn_at_checkpoint()
	else:
		await respawn_at_default_position()


## Apply death feedback — dramatic moment
func _apply_death_feedback() -> void:
	# Heavy camera shake
	var camera = obj.get_node_or_null("Camera2D")
	if camera and camera.has_method("shake"):
		camera.shake(8.0)
	
	# Spawn soul escape particles
	_spawn_death_particles()


## Spawn soul/spirit escape particles — dramatic death burst
func _spawn_death_particles() -> void:
	var burst = GPUParticles2D.new()
	burst.amount = 12
	burst.lifetime = 1.0
	burst.explosiveness = 0.9
	burst.one_shot = true
	burst.z_index = 30
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 50.0
	mat.gravity = Vector3(0, -20, 0)  # Rise up (soul leaving)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = Color(0.9, 0.9, 1.0, 0.8)  # White/ghostly
	burst.process_material = mat
	
	# 4x4 soul wisp texture
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	grad.set_color(1, Color(0.7, 0.8, 1.0, 0.0))
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
	get_tree().create_timer(1.5).timeout.connect(burst.queue_free)


# Hàm này được giữ lại từ File 1
func respawn_at_default_position() -> void:
	# Làm mờ màn hình
	await GameManager.fade_to_black()
	
	# Guard: scene may have changed or obj freed during fade
	if not is_instance_valid(obj) or get_tree() == null:
		return
	
	# Reset trạng thái
	obj.health = obj.max_health
	obj.velocity = Vector2.ZERO
	
	# Tải lại màn chơi hiện tại
	var tree = get_tree()
	if tree != null:
		tree.reload_current_scene()
	
	# (fade_from_black sẽ được gọi bởi hàm _ready() của stage)


# Hàm này lấy từ File 2 (RẤT QUAN TRỌNG)
# Bỏ qua mọi sát thương nhận vào khi player đã chết
func take_damage(_damage: int = 1) -> void:
	pass
