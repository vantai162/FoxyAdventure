extends Node2D
class_name CampFire

## Campfire - Warm light source with particles and flickering glow
## Essential for cave atmosphere - provides safety and light
## Emits sparks, smoke, and warm orange glow
##
## SETUP: Add a PointLight2D child named "FireLight" and configure its
## color, energy, texture_scale, and shadow_enabled in the editor.
## This script handles flicker animation and particle spawning.

@export_group("Flicker Settings")
@export var flicker_enabled: bool = true
@export var flicker_speed: float = 6.0
@export var flicker_intensity: float = 0.25  ## 0.0-1.0, how much energy varies

@export_group("Spark Particles")
@export var emit_sparks: bool = true
@export var spark_count: int = 15
@export var spark_rise_speed: float = 40.0
@export var spark_lifetime: float = 1.5
@export var spark_spread: float = 12.0

@export_group("Smoke Particles")
@export var emit_smoke: bool = true
@export var smoke_count: int = 8
@export var smoke_rise_speed: float = 25.0
@export var smoke_lifetime: float = 2.5

@export_group("Ember Particles")
@export var emit_embers: bool = true
@export var ember_count: int = 6
@export var ember_float_speed: float = 15.0

@export_group("Interaction")
@export var warmth_zone_enabled: bool = false  ## Safe zone for player
@export var warmth_radius: float = 60.0

## Scene node references - configure these in the editor!
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fire_light: PointLight2D = $FireLight

## Runtime particles (spawned dynamically)
var spark_particles: Array[Node2D] = []
var smoke_particles: Array[Node2D] = []
var ember_particles: Array[Node2D] = []

var _flicker_time: float = 0.0
var _spark_timer: float = 0.0
var _smoke_timer: float = 0.0
var _base_energy: float = 1.0  ## Captured from light at start
var _base_color: Color = Color.WHITE

func _ready() -> void:
	# Randomize phase so multiple fires don't sync
	_flicker_time = randf() * TAU
	
	# Play fire animation
	if animated_sprite:
		animated_sprite.play("default")
	
	# Configure light from scene (texture needs to be set if not already)
	if fire_light:
		_base_energy = fire_light.energy  # Capture base from scene
		_base_color = fire_light.color
		if fire_light.texture == null:
			_setup_light_texture()
	
	# Pre-spawn some particles
	if emit_sparks:
		for i in range(spark_count / 3):
			_spawn_spark(true)
	
	if emit_smoke:
		for i in range(smoke_count / 2):
			_spawn_smoke(true)
	
	if emit_embers:
		for i in range(ember_count):
			_spawn_ember()

func _process(delta: float) -> void:
	# Light flickering
	if flicker_enabled and fire_light:
		_update_flicker(delta)
	
	# Spawn particles over time
	if emit_sparks:
		_update_sparks(delta)
	
	if emit_smoke:
		_update_smoke(delta)
	
	if emit_embers:
		_update_embers(delta)

func _setup_light_texture() -> void:
	## Only sets the gradient texture - all other properties configured in scene
	var gradient = GradientTexture2D.new()
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(0.5, 0.0)
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color.TRANSPARENT)
	gradient.gradient = grad
	gradient.width = 256
	gradient.height = 256
	fire_light.texture = gradient

func _update_flicker(delta: float) -> void:
	_flicker_time += delta * flicker_speed
	
	# Multiple overlapping sine waves for organic flicker
	var flicker = sin(_flicker_time) * 0.4
	flicker += sin(_flicker_time * 2.3) * 0.35
	flicker += sin(_flicker_time * 0.7) * 0.25
	flicker = (flicker / 3.0 + 0.5)  # Normalize to 0-1
	
	# Modulate around the base energy set in editor
	fire_light.energy = _base_energy + (flicker - 0.5) * flicker_intensity * 2.0
	
	# Subtle color shift (more orange when brighter)
	var color_shift = flicker * 0.1
	fire_light.color = Color(
		_base_color.r,
		_base_color.g - color_shift * 0.2,
		_base_color.b - color_shift * 0.3,
		1.0
	)

## ============================================================================
## SPARK PARTICLES - Small bright dots rising quickly
## ============================================================================

func _update_sparks(delta: float) -> void:
	_spark_timer += delta
	var spawn_interval = spark_lifetime / float(spark_count)
	
	if _spark_timer >= spawn_interval:
		_spark_timer = 0.0
		_spawn_spark(false)
	
	# Update existing sparks
	var to_remove: Array[Node2D] = []
	for spark in spark_particles:
		if not is_instance_valid(spark):
			to_remove.append(spark)
			continue
		
		var age = spark.get_meta("age", 0.0) + delta
		spark.set_meta("age", age)
		
		if age >= spark_lifetime:
			to_remove.append(spark)
			continue
		
		# Rise with slight horizontal wobble
		var wobble = sin(age * 8.0 + spark.get_meta("phase", 0.0)) * 8.0
		spark.position.y -= spark_rise_speed * delta
		spark.position.x += wobble * delta
		
		# Fade and shrink
		var life_ratio = age / spark_lifetime
		var visual = spark.get_node_or_null("Visual") as Polygon2D
		if visual:
			visual.modulate.a = 1.0 - life_ratio
			var s = 1.0 - life_ratio * 0.5
			visual.scale = Vector2(s, s)
	
	for spark in to_remove:
		spark_particles.erase(spark)
		if is_instance_valid(spark):
			spark.queue_free()

func _spawn_spark(randomize_age: bool) -> void:
	var spark = Node2D.new()
	spark.name = "Spark"
	
	# Random position near fire
	spark.position = Vector2(
		randf_range(-spark_spread, spark_spread),
		randf_range(-8, -16)
	)
	
	spark.set_meta("phase", randf() * TAU)
	spark.set_meta("age", randf() * spark_lifetime * 0.5 if randomize_age else 0.0)
	
	# Create spark visual - tiny bright polygon
	var visual = Polygon2D.new()
	visual.name = "Visual"
	var size = randf_range(1.0, 2.5)
	visual.polygon = PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.5, 0),
		Vector2(0, size * 0.5),
		Vector2(-size * 0.5, 0)
	])
	
	# Random warm color (yellow to orange)
	var hue = randf_range(0.05, 0.12)  # Yellow-orange range
	visual.color = Color.from_hsv(hue, 0.9, 1.0)
	
	spark.add_child(visual)
	add_child(spark)
	spark_particles.append(spark)

## ============================================================================
## SMOKE PARTICLES - Larger, slower, fading gray puffs
## ============================================================================

func _update_smoke(delta: float) -> void:
	_smoke_timer += delta
	var spawn_interval = smoke_lifetime / float(smoke_count)
	
	if _smoke_timer >= spawn_interval:
		_smoke_timer = 0.0
		_spawn_smoke(false)
	
	# Update existing smoke
	var to_remove: Array[Node2D] = []
	for smoke in smoke_particles:
		if not is_instance_valid(smoke):
			to_remove.append(smoke)
			continue
		
		var age = smoke.get_meta("age", 0.0) + delta
		smoke.set_meta("age", age)
		
		if age >= smoke_lifetime:
			to_remove.append(smoke)
			continue
		
		# Rise with gentle drift
		var drift = sin(age * 2.0 + smoke.get_meta("phase", 0.0)) * 5.0
		smoke.position.y -= smoke_rise_speed * delta
		smoke.position.x += drift * delta
		
		# Fade, grow, and become more transparent
		var life_ratio = age / smoke_lifetime
		var visual = smoke.get_node_or_null("Visual") as Polygon2D
		if visual:
			visual.modulate.a = (1.0 - life_ratio) * 0.4  # Smoke is semi-transparent
			var s = 1.0 + life_ratio * 1.5  # Smoke expands
			visual.scale = Vector2(s, s)
	
	for smoke in to_remove:
		smoke_particles.erase(smoke)
		if is_instance_valid(smoke):
			smoke.queue_free()

func _spawn_smoke(randomize_age: bool) -> void:
	var smoke = Node2D.new()
	smoke.name = "Smoke"
	
	# Start above fire
	smoke.position = Vector2(
		randf_range(-6, 6),
		randf_range(-20, -28)
	)
	
	smoke.set_meta("phase", randf() * TAU)
	smoke.set_meta("age", randf() * smoke_lifetime * 0.3 if randomize_age else 0.0)
	
	# Create smoke visual - soft circle approximation
	var visual = Polygon2D.new()
	visual.name = "Visual"
	var size = randf_range(4.0, 7.0)
	
	# Irregular blob shape
	var points: PackedVector2Array = []
	for i in range(8):
		var angle = (float(i) / 8.0) * TAU
		var r = size * randf_range(0.7, 1.0)
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
	visual.polygon = points
	
	# Gray smoke with slight variation
	var gray = randf_range(0.25, 0.4)
	visual.color = Color(gray, gray, gray, 0.4)
	
	smoke.add_child(visual)
	add_child(smoke)
	smoke_particles.append(smoke)

## ============================================================================
## EMBER PARTICLES - Glowing dots that hover near fire
## ============================================================================

func _update_embers(delta: float) -> void:
	for ember in ember_particles:
		if not is_instance_valid(ember):
			continue
		
		var time = Time.get_ticks_msec() / 1000.0
		var phase = ember.get_meta("phase", 0.0)
		var base_pos = ember.get_meta("base_pos", Vector2.ZERO)
		
		# Gentle floating motion
		ember.position.x = base_pos.x + sin(time * 1.5 + phase) * 6.0
		ember.position.y = base_pos.y + sin(time * 2.0 + phase * 1.3) * 4.0
		
		# Pulsing glow
		var visual = ember.get_node_or_null("Visual") as Polygon2D
		if visual:
			var pulse = sin(time * 3.0 + phase) * 0.5 + 0.5
			visual.modulate.a = 0.5 + pulse * 0.5

func _spawn_ember() -> void:
	var ember = Node2D.new()
	ember.name = "Ember"
	
	# Random position around fire
	var base_pos = Vector2(
		randf_range(-15, 15),
		randf_range(-5, -20)
	)
	ember.position = base_pos
	ember.set_meta("base_pos", base_pos)
	ember.set_meta("phase", randf() * TAU)
	
	# Create ember visual - tiny glowing dot
	var visual = Polygon2D.new()
	visual.name = "Visual"
	var size = randf_range(1.0, 2.0)
	visual.polygon = PackedVector2Array([
		Vector2(0, -size),
		Vector2(size, 0),
		Vector2(0, size),
		Vector2(-size, 0)
	])
	
	# Orange-red glow
	visual.color = Color(1.0, randf_range(0.3, 0.5), 0.1, 0.8)
	
	ember.add_child(visual)
	add_child(ember)
	ember_particles.append(ember)

## Extinguish the fire (for gameplay mechanics)
func extinguish() -> void:
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.visible = false
	
	if fire_light:
		var tween = create_tween()
		tween.tween_property(fire_light, "energy", 0.0, 0.5)
	
	emit_sparks = false
	emit_smoke = false
	emit_embers = false
	
	# Clear particles
	for spark in spark_particles:
		if is_instance_valid(spark):
			spark.queue_free()
	for smoke in smoke_particles:
		if is_instance_valid(smoke):
			smoke.queue_free()
	for ember in ember_particles:
		if is_instance_valid(ember):
			ember.queue_free()
	
	spark_particles.clear()
	smoke_particles.clear()
	ember_particles.clear()

## Re-ignite the fire
func ignite() -> void:
	if animated_sprite:
		animated_sprite.visible = true
		animated_sprite.play("default")
	
	emit_sparks = true
	emit_smoke = true
	emit_embers = true
	
	if fire_light:
		var tween = create_tween()
		tween.tween_property(fire_light, "energy", light_energy, 0.3)
	
	# Respawn embers
	for i in range(ember_count):
		_spawn_ember()
