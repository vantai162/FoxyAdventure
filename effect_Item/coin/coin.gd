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
	
	# Pulsing glow - subtle breathing, not disco ball
	if _glow:
		_glow.energy = 0.2 + sin(_time * 2.0) * 0.08  # Was 0.4 ± 0.2, now 0.2 ± 0.08

func _setup_glow() -> void:
	## Coin is 11×11 px. Glow should be a subtle halo, not a blob.
	## Target: ~14px diameter glow (just slightly larger than coin)
	## Using 16px texture at 0.15 scale = 2.4px visible radius = ~5px diameter
	## But we want ~14px, so 16px texture at 0.4 scale = 6.4px, energy low
	## Actually: 16×0.9 = 14.4px. Perfect.
	_glow = get_node_or_null("CoinGlow")
	if _glow:
		return
	
	_glow = PointLight2D.new()
	_glow.name = "CoinGlow"
	_glow.color = Color(1.0, 0.85, 0.2)  # Gold
	_glow.energy = 0.25  # Was 0.5 - halved for subtlety
	_glow.texture_scale = 0.2  # Was 0.4 - 16px × 0.2 = 3.2px radius = 6.4px diameter (tight halo)
	_glow.blend_mode = Light2D.BLEND_MODE_ADD
	_glow.z_index = ZLayers.LIGHT_EFFECT  # Light effect layer
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 16  # Was 64 - reduced to match pixel scale
	tex.height = 16
	_glow.texture = tex
	
	add_child(_glow)

func _setup_sparkles() -> void:
	## Coin is 11×11 px. Sparkles should be tiny glints, 1-2px visual.
	## NOT a shower of gradient orbs.
	## Target: 2-3 particles, 4px texture at small scale, point emission.
	_sparkle_particles = get_node_or_null("Sparkles")
	if _sparkle_particles:
		return
	
	_sparkle_particles = GPUParticles2D.new()
	_sparkle_particles.name = "Sparkles"
	_sparkle_particles.amount = 2  # Was 4 - coins don't need particle showers
	_sparkle_particles.lifetime = 0.4  # Was 0.6 - snappier
	_sparkle_particles.explosiveness = 0.9  # Was 0.8 - more burst-like
	_sparkle_particles.randomness = 0.3  # Was 0.5 - tighter pattern
	_sparkle_particles.z_index = ZLayers.EFFECT_FRONT  # Sparkles visible above coin
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT  # Was SPHERE 6.0 - now point emission from center
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 90.0  # Was 180 - tighter spread upward
	mat.initial_velocity_min = 8.0  # Was 15 - slower, more elegant
	mat.initial_velocity_max = 16.0  # Was 30 - controlled
	mat.gravity = Vector3(0, 15, 0)  # Was 20 - slight fall
	mat.scale_min = 0.5  # Was 0.3 - will be tiny with 4px texture
	mat.scale_max = 1.0  # Was 0.6 - max 4px sparkle
	mat.color = Color(1.0, 0.95, 0.6, 1.0)  # Slightly brighter gold
	_sparkle_particles.process_material = mat
	
	# Tiny sparkle texture - 4px is enough for a glint
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 0.9, 1))
	grad.set_color(1, Color(1, 1, 0.8, 0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 4  # Was 16 - now properly tiny
	tex.height = 4
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
		
		# Collection burst effect - subtle, not a firework
		if _sparkle_particles:
			_sparkle_particles.explosiveness = 1.0
			_sparkle_particles.amount = 5  # Was 12 - modest burst for 11px coin
			_sparkle_particles.one_shot = true
			_sparkle_particles.restart()
		
		# Play collection animation
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("collected")
			await $AnimatedSprite2D.animation_finished
		else:
			await get_tree().create_timer(0.3).timeout
		
		queue_free()
