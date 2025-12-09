extends Area2D
class_name Coin
## Collectible Coin - Designer-friendly with full visual feedback
## Features: float, spin animation, GPU glow, sparkle particles

@export_group("Reward")
@export var coin_value: int = 1  ## How many coins this gives

@export_group("Visual")
@export var float_animation: bool = true  ## Gentle floating motion
@export var float_amplitude: float = 3.0  ## How far up/down
@export var float_speed: float = 2.0
@export var sparkle_enabled: bool = true  ## Occasional sparkle effect
@export var glow_enabled: bool = true  ## GPU light glow

@export_group("Audio")
@export var collect_sound: AudioStream  ## Sound when collected

var _original_y: float
var _time: float = 0.0
var _collected: bool = false
var _glow: PointLight2D = null
var _sparkle_particles: GPUParticles2D = null

func _ready() -> void:
	_original_y = position.y
	_time = randf() * TAU  # Random phase so coins don't sync
	
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default")
	
	# Setup GPU glow
	if glow_enabled:
		_setup_glow()
	
	# Setup sparkle particles
	if sparkle_enabled:
		_setup_sparkles()

func _process(delta: float) -> void:
	if _collected:
		return
	
	_time += delta * float_speed
	
	# Float animation
	if float_animation:
		position.y = _original_y + sin(_time) * float_amplitude
	
	# Pulsing glow
	if _glow:
		_glow.energy = 0.4 + sin(_time * 2.0) * 0.2

func _setup_glow() -> void:
	_glow = get_node_or_null("CoinGlow")
	if _glow:
		return
	
	_glow = PointLight2D.new()
	_glow.name = "CoinGlow"
	_glow.color = Color(1.0, 0.85, 0.2)  # Gold
	_glow.energy = 0.5
	_glow.texture_scale = 0.4
	_glow.blend_mode = Light2D.BLEND_MODE_ADD
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	_glow.texture = tex
	
	add_child(_glow)

func _setup_sparkles() -> void:
	_sparkle_particles = get_node_or_null("Sparkles")
	if _sparkle_particles:
		return
	
	_sparkle_particles = GPUParticles2D.new()
	_sparkle_particles.name = "Sparkles"
	_sparkle_particles.amount = 4
	_sparkle_particles.lifetime = 0.6
	_sparkle_particles.explosiveness = 0.8
	_sparkle_particles.randomness = 0.5
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, 20, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	mat.color = Color(1.0, 0.95, 0.5, 1.0)
	_sparkle_particles.process_material = mat
	
	# Small sparkle texture
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 0.8, 1))
	grad.set_color(1, Color(1, 1, 0.8, 0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 16
	tex.height = 16
	_sparkle_particles.texture = tex
	
	add_child(_sparkle_particles)

func _on_area_entered(area: Area2D) -> void:
	if _collected:
		return
	
	var player = area.get_parent()
	if not player.has_method("inventory") and not player.get("inventory"):
		player = area.get_parent()
	
	if player and (player.has_node("inventory") or player.get("inventory")):
		_collected = true
		
		# Give coins
		player.inventory.adjust_amount_item("Coin", coin_value)
		
		# Play sound using AudioManager
		AudioManager.play_sound("coin_collected", 15.0)
		
		# Collection burst effect
		if _sparkle_particles:
			_sparkle_particles.explosiveness = 1.0
			_sparkle_particles.amount = 12
			_sparkle_particles.one_shot = true
			_sparkle_particles.restart()
		
		# Play collection animation
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("collected")
			await $AnimatedSprite2D.animation_finished
		else:
			await get_tree().create_timer(0.3).timeout
		
		queue_free()
