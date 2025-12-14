extends Area2D
class_name KeyPickup
## Collectible key with optional ID for matching specific locks
## Features: float, color glow, shimmer, pickup particles

@export_group("Key Identity")
@export var key_id: String = ""  ## Unique ID to match with locks (empty = generic key, works with has_key())
@export var key_color: Color = Color.YELLOW  ## Visual tint for the key

@export_group("Pickup Effects")
@export var play_sound: bool = true
@export var show_particles: bool = true
@export var float_animation: bool = true
@export var float_amplitude: float = 4.0
@export var float_speed: float = 2.0
@export var glow_enabled: bool = true

var _start_y: float = 0.0
var _time: float = 0.0
var _glow: PointLight2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null

func _ready() -> void:
	if sprite:
		sprite.play("default")
		sprite.modulate = key_color
	
	_start_y = position.y
	_time = randf() * TAU  # Random phase for multiple keys
	
	# Connect area signal
	area_entered.connect(_on_area_entered)
	
	# Setup glow
	if glow_enabled:
		_setup_glow()

func _process(delta: float) -> void:
	_time += delta * float_speed
	
	if float_animation:
		position.y = _start_y + sin(_time) * float_amplitude
	
	# Pulsing glow matching key color - subtle, not strobe
	if _glow:
		_glow.energy = 0.25 + sin(_time * 1.5) * 0.1  # Was 0.5 ± 0.25, now 0.25 ± 0.1

func _setup_glow() -> void:
	## Key is 20×24 px. Glow should be a subtle colored aura matching key_color.
	## Target: ~24px diameter glow (16px × 1.0 = 16px radius... but we want ~24px)
	## So 16px × 1.5 = 24px diameter - snug around key.
	_glow = get_node_or_null("KeyGlow")
	if _glow:
		_glow.color = key_color
		return
	
	_glow = PointLight2D.new()
	_glow.name = "KeyGlow"
	_glow.color = key_color
	_glow.energy = 0.3  # Was 0.6 - halved
	_glow.texture_scale = 0.8  # Was 0.5 - with 16px texture = 12.8px, slightly larger than key
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
	tex.width = 16  # Was 64 - proper pixel scale
	tex.height = 16
	_glow.texture = tex
	
	add_child(_glow)

func _on_area_entered(area: Area2D) -> void:
	var player = area.get_parent()
	if not player is Player:
		return
	
	# Add key to inventory with ID
	if key_id.is_empty():
		player.inventory.adjust_amount_item("Key", 1)
	else:
		player.inventory.adjust_amount_item("Key_" + key_id, 1)
	
	# Visual/audio feedback using AudioManager
	if play_sound:
		AudioManager.play_sound("coin_collected", 15.0)
	
	if show_particles:
		_spawn_pickup_particles()
	
	# Hide immediately, cleanup after brief delay for particles
	visible = false
	set_process(false)
	
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _spawn_pickup_particles() -> void:
	## Create simple pickup particle effect
	var particles = GPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.5
	particles.global_position = global_position
	particles.z_index = ZLayers.EFFECT_FRONT  # Pickup effect visible
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 8.0
	material.direction = Vector3(0, -1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.gravity = Vector3(0, 200, 0)
	material.color = key_color
	particles.process_material = material
	
	get_tree().current_scene.add_child(particles)
	
	# Auto-cleanup
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## Check if this key matches a specific lock ID
func matches_lock(lock_id: String) -> bool:
	if key_id.is_empty() or lock_id.is_empty():
		return true  # Generic keys match any lock
	return key_id == lock_id
