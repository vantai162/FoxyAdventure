extends pick_up_item
class_name TrapCoin
## Fake coin that applies negative effect when collected
## Looks like a real coin but has subtle "off" visual hints

## Inherited from pick_up_item:
## @export var effect_name: String  ## Effect to apply
## @export var duration: float  ## How long effect lasts

@export_group("Visual Disguise")
@export var looks_like_coin: bool = true  ## Use coin animation
@export var reveal_on_collect: bool = true  ## Flash red when triggered
@export var float_animation: bool = true  ## Match real coins
@export var float_amplitude: float = 3.0
@export var float_speed: float = 2.0
@export var subtle_evil_hint: bool = true  ## Slight color shift

@export_group("Audio")
@export var trap_sound: AudioStream  ## Evil sound when triggered

var _collected: bool = false
var _start_y: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	_start_y = position.y
	_time = randf() * TAU
	
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default")
		# Subtle evil tint - slightly desaturated/greenish
		if subtle_evil_hint:
			$AnimatedSprite2D.modulate = Color(0.95, 1.0, 0.85, 1.0)

func _process(delta: float) -> void:
	if _collected:
		return
	
	_time += delta * float_speed
	
	# Float like real coins to maintain disguise
	if float_animation:
		position.y = _start_y + sin(_time) * float_amplitude

func _on_area_entered(area: Area2D) -> void:
	if _collected:
		return
	
	var player = area.get_parent()
	if not player or not player.has_method("_applyeffect"):
		return
	
	_collected = true
	
	# Apply trap effect
	player._applyeffect(effect_name, duration)
	
	# Visual feedback - flash red with evil glow burst
	if reveal_on_collect and has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color.RED
		
		# Create evil burst particles
		var burst = GPUParticles2D.new()
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.amount = 8
		burst.lifetime = 0.4
		burst.z_index = ZLayers.EFFECT_FRONT  # Burst above collectible
		
		var mat = ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 8.0
		mat.direction = Vector3(0, 0, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 40.0
		mat.initial_velocity_max = 80.0
		mat.gravity = Vector3(0, 50, 0)
		mat.color = Color(0.8, 0.1, 0.1, 1.0)  # Evil red
		burst.process_material = mat
		
		var grad = Gradient.new()
		grad.set_color(0, Color(1, 0.2, 0.2, 1))
		grad.set_color(1, Color(0.5, 0, 0, 0))
		var tex = GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.width = 16
		tex.height = 16
		burst.texture = tex
		
		add_child(burst)
		burst.restart()
		
		var tween = create_tween()
		tween.tween_property($AnimatedSprite2D, "modulate:a", 0.0, 0.3)
	
	# Play trap sound
	if trap_sound:
		var audio = AudioStreamPlayer2D.new()
		audio.stream = trap_sound
		audio.bus = "SFX"
		get_parent().add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
	
	# Small delay before disappearing
	await get_tree().create_timer(0.4).timeout
	queue_free()
