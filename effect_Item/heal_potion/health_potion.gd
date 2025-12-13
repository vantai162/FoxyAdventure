extends Area2D
class_name HealthPotion
## Health pickup - Restores player health when collected
## Features: float, GPU glow, bubble particles, shimmer effect

@export_group("Healing")
@export var heal_amount: int = 1  ## How much health to restore

@export_group("Visual")
@export var float_animation: bool = true
@export var float_amplitude: float = 3.0
@export var float_speed: float = 1.5
@export var glow_enabled: bool = true
@export var bubbles_enabled: bool = true

@export_group("Audio")
@export var pickup_sound: AudioStream  ## Override default sound

var _original_y: float
var _time: float = 0.0
var _collected: bool = false
var _glow: PointLight2D = null
var _bubbles: GPUParticles2D = null

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer if has_node("AudioStreamPlayer") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	_original_y = position.y
	_time = randf() * TAU
	
	if glow_enabled:
		_setup_glow()
	
	if bubbles_enabled:
		_setup_bubbles()

func _process(delta: float) -> void:
	if _collected:
		return
	
	_time += delta * float_speed
	
	# Float animation
	if float_animation:
		position.y = _original_y + sin(_time) * float_amplitude
	
	# Pulsing glow - gentle heartbeat, not strobe
	if _glow:
		_glow.energy = 0.25 + sin(_time * 1.8) * 0.1  # Was 0.5 ± 0.25, now 0.25 ± 0.1
	
	# Shimmer on sprite
	if sprite:
		var shimmer = 0.9 + sin(_time * 3.0) * 0.1
		sprite.modulate = Color(shimmer, shimmer, shimmer, 1.0)

func _setup_glow() -> void:
	## Potion is ~22×28 px (scaled 2×). Glow should be a warm aura.
	## Target: ~24px diameter glow (16px × 1.5 = 24px, snug around potion)
	## Also fixing color: healing should be GREEN, not red/pink.
	_glow = get_node_or_null("PotionGlow")
	if _glow:
		return
	
	_glow = PointLight2D.new()
	_glow.name = "PotionGlow"
	_glow.color = Color(0.3, 0.9, 0.4)  # Was (1.0, 0.3, 0.4) red/pink - now healing green
	_glow.energy = 0.3  # Was 0.6 - halved
	_glow.texture_scale = 0.6  # Was 0.5 - with 16px texture = 9.6px radius = ~20px diameter
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

func _setup_bubbles() -> void:
	## Bubbles should be tiny (2-4px) and sparse, rising from potion.
	## Color should match healing theme (soft green/white, not pink).
	_bubbles = get_node_or_null("Bubbles")
	if _bubbles:
		return
	
	_bubbles = GPUParticles2D.new()
	_bubbles.name = "Bubbles"
	_bubbles.amount = 2  # Was 3 - sparser for small item
	_bubbles.lifetime = 0.8  # Was 1.0 - quicker rise
	_bubbles.preprocess = 0.3  # Was 0.5
	_bubbles.z_index = ZLayers.EFFECT_FRONT  # Bubbles visible above potion
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(2, 1, 0)  # Was 3 - tighter
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 15.0  # Was 20 - more vertical
	mat.initial_velocity_min = 6.0  # Was 8 - gentler
	mat.initial_velocity_max = 12.0  # Was 15
	mat.gravity = Vector3(0, -4, 0)  # Was -5 - gentler float
	mat.scale_min = 0.3  # Was 0.2
	mat.scale_max = 0.6  # Was 0.5 - with 4px texture = 1.2-2.4px bubbles
	mat.color = Color(0.7, 1.0, 0.8, 0.6)  # Was (1.0, 0.5, 0.6) pink - now soft green/white
	_bubbles.process_material = mat
	
	# Tiny bubble texture
	var grad = Gradient.new()
	grad.set_color(0, Color(0.85, 1.0, 0.9, 0.7))  # Was (1, 0.8, 0.85) pink
	grad.set_color(1, Color(0.7, 1.0, 0.8, 0))  # Was (1, 0.6, 0.7) pink
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 4  # Was 8 - tiny pixel bubbles
	tex.height = 4
	_bubbles.texture = tex
	
	# Position bubbles at liquid area
	_bubbles.position = Vector2(0, -2)
	add_child(_bubbles)

func _on_area_entered(area: Area2D) -> void:
	if _collected:
		return
	
	var player = area.get_parent()
	if not player or not player.has_method("checkfullhealth"):
		return
	
	# Don't collect if already at full health
	if player.checkfullhealth():
		return
	
	_collected = true
	
	# Burst effect
	if _glow:
		var tween = create_tween()
		tween.tween_property(_glow, "energy", 2.0, 0.15)
		tween.tween_property(_glow, "energy", 0.0, 0.15)
	
	# Hide immediately
	hide()
	
	# Heal player
	player.heal(heal_amount)
	
	# Play sound using AudioManager
	AudioManager.play_sound("heal", 20.0)
	
	# Brief delay for sound to play
	await get_tree().create_timer(0.3).timeout
	queue_free()
