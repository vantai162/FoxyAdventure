extends PointLight2D
class_name PlayerTorch

## Torch light that follows the player
## Flickers and can be extinguished
## Casts shadows when walls have LightOccluder2D

@export_group("Torch Settings")
@export var base_energy: float = 1.0
@export var base_radius: float = 200.0
@export var flicker_enabled: bool = true
@export var flicker_speed: float = 8.0
@export var flicker_intensity: float = 0.15

@export_group("Shadow Settings")
@export var cast_shadows: bool = true  ## Enable shadow casting (walls block light)

@export_group("State")
@export var is_lit: bool = true

var _flicker_time: float = 0.0

func _ready() -> void:
	texture_scale = base_radius / 512.0
	energy = base_energy
	enabled = is_lit
	shadow_enabled = cast_shadows
	
	# Create radial gradient texture if none exists
	if texture == null:
		_create_light_texture()

func _create_light_texture() -> void:
	var gradient = GradientTexture2D.new()
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(0.5, 0.0)
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color.TRANSPARENT)
	gradient.gradient = grad
	gradient.width = 512
	gradient.height = 512
	texture = gradient

func _process(delta: float) -> void:
	if not is_lit:
		return
	
	if flicker_enabled:
		_flicker_time += delta * flicker_speed
		var flicker = sin(_flicker_time) * sin(_flicker_time * 0.7) * flicker_intensity
		energy = base_energy + flicker
		
		# Slight scale variation for more organic feel
		var scale_flicker = 1.0 + sin(_flicker_time * 1.3) * 0.02
		texture_scale = (base_radius / 512.0) * scale_flicker

func light_torch() -> void:
	is_lit = true
	enabled = true
	
	# Fade in effect
	var tween = create_tween()
	energy = 0
	tween.tween_property(self, "energy", base_energy, 0.3)

func extinguish_torch() -> void:
	is_lit = false
	
	# Fade out effect
	var tween = create_tween()
	tween.tween_property(self, "energy", 0.0, 0.2)
	await tween.finished
	enabled = false

func set_radius(new_radius: float) -> void:
	base_radius = new_radius
	texture_scale = base_radius / 512.0
