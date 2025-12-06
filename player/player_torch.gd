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

@export_group("Spark Particles")
@export var emit_sparks: bool = true
@export var spark_spawn_interval: float = 0.4  ## Seconds between spark bursts
@export var sparks_per_burst: int = 2
@export var spark_lifetime: float = 0.6
@export var spark_speed: float = 30.0

@export_group("State")
@export var is_lit: bool = true

var _flicker_time: float = 0.0
var _spark_timer: float = 0.0
var _sparks: Array[Node2D] = []

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
	
	# Spark particles
	if emit_sparks:
		_update_sparks(delta)

func light_torch() -> void:
	is_lit = true
	enabled = true
	
	# Fade in effect
	var tween = create_tween()
	energy = 0
	tween.tween_property(self, "energy", base_energy, 0.3)

func extinguish_torch() -> void:
	is_lit = false
	emit_sparks = false
	_clear_sparks()
	
	# Fade out effect
	var tween = create_tween()
	tween.tween_property(self, "energy", 0.0, 0.2)
	await tween.finished
	enabled = false

func set_radius(new_radius: float) -> void:
	base_radius = new_radius
	texture_scale = base_radius / 512.0

## ============================================================================
## SPARK PARTICLES
## Small bright sparks that occasionally fly off the torch
## ============================================================================

func _update_sparks(delta: float) -> void:
	_spark_timer += delta
	
	if _spark_timer >= spark_spawn_interval:
		_spark_timer = 0.0
		for i in range(sparks_per_burst):
			_spawn_spark()
	
	# Update existing sparks
	var to_remove: Array[Node2D] = []
	for spark in _sparks:
		if not is_instance_valid(spark):
			to_remove.append(spark)
			continue
		
		var age = spark.get_meta("age", 0.0) + delta
		spark.set_meta("age", age)
		
		if age >= spark_lifetime:
			to_remove.append(spark)
			continue
		
		# Apply velocity (sparks drift upward and outward)
		var velocity = spark.get_meta("velocity", Vector2.ZERO) as Vector2
		velocity.y -= 20.0 * delta  # Slight upward drift
		spark.set_meta("velocity", velocity)
		spark.position += velocity * delta
		
		# Fade out
		var life_ratio = age / spark_lifetime
		var visual = spark.get_node_or_null("Visual") as Polygon2D
		if visual:
			visual.modulate.a = 1.0 - life_ratio
			# Shrink
			var s = 1.0 - life_ratio * 0.5
			visual.scale = Vector2(s, s)
	
	for spark in to_remove:
		_sparks.erase(spark)
		if is_instance_valid(spark):
			spark.queue_free()

func _spawn_spark() -> void:
	var spark = Node2D.new()
	spark.name = "Spark"
	
	# Start near torch center
	spark.position = Vector2(randf_range(-3, 3), randf_range(-5, 0))
	
	# Random outward velocity
	var angle = randf_range(-PI * 0.8, -PI * 0.2)  # Mostly upward
	var velocity = Vector2(cos(angle), sin(angle)) * spark_speed * randf_range(0.5, 1.2)
	spark.set_meta("velocity", velocity)
	spark.set_meta("age", 0.0)
	
	# Create spark visual - tiny bright diamond
	var visual = Polygon2D.new()
	visual.name = "Visual"
	var size = randf_range(1.0, 2.0)
	visual.polygon = PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.5, 0),
		Vector2(0, size * 0.5),
		Vector2(-size * 0.5, 0)
	])
	
	# Warm yellow-orange color
	var hue = randf_range(0.08, 0.15)
	visual.color = Color.from_hsv(hue, 0.9, 1.0)
	
	spark.add_child(visual)
	add_child(spark)
	_sparks.append(spark)

## Clear all sparks (when extinguished)
func _clear_sparks() -> void:
	for spark in _sparks:
		if is_instance_valid(spark):
			spark.queue_free()
	_sparks.clear()
