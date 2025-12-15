extends Area2D
class_name BladePickup
## Blade projectile pickup - collectible with satisfying visual feedback
## Features: floating animation, spin, glow pulse, sparkle particles

@export_group("Visual")
@export var float_amplitude: float = 4.0  ## How far up/down
@export var float_speed: float = 2.5
@export var spin_speed: float = 120.0  ## Degrees per second
@export var enable_glow: bool = true

var is_collected: bool = false
var _start_y: float = 0.0
var _float_time: float = 0.0
var _glow: PointLight2D = null
var _sprite: Node2D = null

func _ready() -> void:
	_start_y = position.y
	_float_time = randf() * TAU  # Random phase
	
	# Get or create visual components
	_sprite = get_node_or_null("Sprite2D")
	_glow = get_node_or_null("BladeGlow")
	
	# Create glow if not present
	if enable_glow and not _glow:
		_create_glow()

func _process(delta: float) -> void:
	if is_collected:
		return
	
	# Floating animation
	_float_time += delta * float_speed
	position.y = _start_y + sin(_float_time) * float_amplitude
	
	# Spin animation
	if _sprite:
		_sprite.rotation_degrees += spin_speed * delta
	
	# Pulsing glow - subtle breathing, not pulsating orb
	if _glow:
		_glow.energy = 0.25 + sin(_float_time * 1.5) * 0.1  # Was 0.5 ± 0.25, now 0.25 ± 0.1

func _create_glow() -> void:
	## Blade pickup is 13×10 px. Glow should be a subtle metallic shimmer.
	## Target: ~16px diameter glow (16px texture × 1.0 scale = 16px)
	## But we want tighter, so 16px × 0.8 = 12.8px glow around 13px blade.
	_glow = PointLight2D.new()
	_glow.name = "BladeGlow"
	_glow.color = Color(0.6, 0.8, 1.0)  # Cool blue metallic
	_glow.energy = 0.3  # Was 0.6 - halved
	_glow.texture_scale = 0.8  # Was 0.4 - with 16px texture = 12.8px glow
	_glow.blend_mode = Light2D.BLEND_MODE_ADD
	_glow.z_index = ZLayers.LIGHT_EFFECT  # Light effect layer
	
	# Create radial gradient texture
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
	if is_collected:
		return

	var parent = area.get_parent()
	if parent is Player:
		is_collected = true
		
		# Collection effect: quick spin + shrink
		var tween = create_tween()
		tween.set_parallel(true)
		if _sprite:
			tween.tween_property(_sprite, "rotation_degrees", _sprite.rotation_degrees + 360, 0.2)
			tween.tween_property(_sprite, "scale", Vector2.ZERO, 0.2)
		if _glow:
			tween.tween_property(_glow, "energy", 0.6, 0.1)  # Was 2.0 - too bright
			tween.chain().tween_property(_glow, "energy", 0.0, 0.1)
		
		# Give blade to player (false = NOT an upgrade, just filling a slot)
		# true would increase max capacity, which is wrong for a scrap pickup
		if parent.has_method("_collect_blade"):
			parent._collect_blade(false)
		
		# Audio feedback
		AudioManager.play_sound("coin_collected", 10.0)
		
		await tween.finished
		queue_free()
