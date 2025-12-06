extends Node2D
class_name FlameHazard

## Cycling flame hazard that also emits light
## Can be used both as a hazard and a light source in dark areas
##
## SETUP: Scene includes FlameLight PointLight2D - configure color/energy/texture_scale
## in the editor. Script handles on/off cycling and flicker animation.

@export_group("Flame Settings")
@export var cycle_enabled: bool = true  ## If false, flame stays on permanently
@export var on_duration: float = 2.0  ## How long flame stays active
@export var off_duration: float = 1.5  ## How long flame stays off

@export_group("Spark Particles")
@export var emit_sparks: bool = true
@export var spark_count: int = 8
@export var spark_spawn_interval: float = 0.15
@export var spark_lifetime: float = 0.5
@export var spark_speed: float = 40.0

@export_group("Damage")
@export var damage: int = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area_1: Area2D = $HitArea2D
@onready var hit_area_2: Area2D = $HitArea2D2
@onready var flame_light: PointLight2D = $FlameLight

var is_active: bool = false
var current_phase: String = "off"
var _sparks: Array[Node2D] = []
var _spark_timer: float = 0.0
var _base_energy: float = 0.8
var _base_color: Color = Color(1.0, 0.7, 0.3, 1.0)

func _ready() -> void:
	# Setup collisions as disabled initially
	_set_collision_enabled(false)
	
	# Capture base values from scene-configured light
	if flame_light:
		_base_energy = flame_light.energy
		_base_color = flame_light.color
		flame_light.energy = 0  # Start off
		if flame_light.texture == null:
			_setup_light_texture()
	
	# Start the cycle
	if cycle_enabled:
		play_cycle()
	else:
		# Permanent flame
		await start_phase()
		await active_phase_loop()

func _process(delta: float) -> void:
	# Update spark particles when flame is active
	if emit_sparks and is_active:
		_update_sparks(delta)

func _setup_light_texture() -> void:
	## Only sets texture if missing - other properties configured in scene
	var gradient_tex = GradientTexture2D.new()
	gradient_tex.width = 512
	gradient_tex.height = 512
	gradient_tex.fill = GradientTexture2D.FILL_RADIAL
	gradient_tex.fill_from = Vector2(0.5, 0.5)
	gradient_tex.fill_to = Vector2(0.5, 0.0)
	
	var gradient = Gradient.new()
	gradient.colors = [Color.WHITE, Color(1, 1, 1, 0)]
	gradient.offsets = [0.0, 1.0]
	gradient_tex.gradient = gradient
	
	flame_light.texture = gradient_tex

func play_cycle() -> void:
	while true:
		await start_phase()
		await active_phase()
		await end_phase()
		await off_phase()

func start_phase() -> void:
	current_phase = "starting"
	animated_sprite.play("start")
	_set_collision_enabled(true)
	
	# Fade in light
	if flame_light:
		var tween = create_tween()
		tween.tween_property(flame_light, "energy", _base_energy, 0.3)
	
	await animated_sprite.animation_finished

func active_phase() -> void:
	current_phase = "active"
	is_active = true
	animated_sprite.play("active")
	_set_collision_enabled(true)
	
	# Add light flicker during active phase
	if flame_light:
		_start_flicker()
	
	await get_tree().create_timer(on_duration).timeout
	
	if flame_light:
		_stop_flicker()

func active_phase_loop() -> void:
	# For permanent flames - loop the active animation
	current_phase = "active"
	is_active = true
	animated_sprite.play("active")
	_set_collision_enabled(true)
	
	if flame_light:
		flame_light.energy = _base_energy
		_start_flicker()
	
	# Keep looping animation
	animated_sprite.animation_looped.connect(_on_active_loop)

func _on_active_loop() -> void:
	if current_phase == "active":
		animated_sprite.play("active")

func end_phase() -> void:
	current_phase = "ending"
	is_active = false
	animated_sprite.play("end")
	_set_collision_enabled(false)
	
	# Clear sparks
	_clear_sparks()
	
	# Fade out light
	if flame_light:
		var tween = create_tween()
		tween.tween_property(flame_light, "energy", 0.0, 0.2)
	
	await animated_sprite.animation_finished

func off_phase() -> void:
	current_phase = "off"
	await get_tree().create_timer(off_duration).timeout

func _set_collision_enabled(enabled: bool) -> void:
	if hit_area_1 and hit_area_1.has_node("CollisionShape2D"):
		hit_area_1.get_node("CollisionShape2D").disabled = not enabled
	if hit_area_2 and hit_area_2.has_node("CollisionShape2D"):
		hit_area_2.get_node("CollisionShape2D").disabled = not enabled

var _flicker_tween: Tween

func _start_flicker() -> void:
	if flame_light == null:
		return
	
	_flicker_tween = create_tween()
	_flicker_tween.set_loops()
	_flicker_tween.tween_property(flame_light, "energy", _base_energy * 1.1, 0.1)
	_flicker_tween.tween_property(flame_light, "energy", _base_energy * 0.9, 0.15)
	_flicker_tween.tween_property(flame_light, "energy", _base_energy, 0.1)

func _stop_flicker() -> void:
	if _flicker_tween:
		_flicker_tween.kill()
		_flicker_tween = null

## Force flame on (for puzzle interactions)
func ignite() -> void:
	if current_phase == "off" or current_phase == "ending":
		# Skip to start phase
		await start_phase()

## Force flame off
func extinguish() -> void:
	if is_active:
		await end_phase()

## ============================================================================
## SPARK PARTICLES
## Small sparks that fly off during active flame phase
## ============================================================================

func _update_sparks(delta: float) -> void:
	_spark_timer += delta
	
	if _spark_timer >= spark_spawn_interval and _sparks.size() < spark_count:
		_spark_timer = 0.0
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
		
		# Apply velocity
		var velocity = spark.get_meta("velocity", Vector2.ZERO) as Vector2
		velocity.y -= 30.0 * delta  # Upward drift
		spark.set_meta("velocity", velocity)
		spark.position += velocity * delta
		
		# Fade and shrink
		var life_ratio = age / spark_lifetime
		var visual = spark.get_node_or_null("Visual") as Polygon2D
		if visual:
			visual.modulate.a = 1.0 - life_ratio
			var s = 1.0 - life_ratio * 0.6
			visual.scale = Vector2(s, s)
	
	for spark in to_remove:
		_sparks.erase(spark)
		if is_instance_valid(spark):
			spark.queue_free()

func _spawn_spark() -> void:
	var spark = Node2D.new()
	spark.name = "Spark"
	
	# Start near flame center
	spark.position = Vector2(randf_range(-15, 5), randf_range(-10, 10))
	
	# Random mostly-upward velocity
	var angle = randf_range(-PI * 0.75, -PI * 0.25)
	var velocity = Vector2(cos(angle), sin(angle)) * spark_speed * randf_range(0.6, 1.2)
	spark.set_meta("velocity", velocity)
	spark.set_meta("age", 0.0)
	
	# Create spark visual
	var visual = Polygon2D.new()
	visual.name = "Visual"
	var size = randf_range(1.5, 3.0)
	visual.polygon = PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.5, 0),
		Vector2(0, size * 0.5),
		Vector2(-size * 0.5, 0)
	])
	
	# Yellow-orange spark color
	var hue = randf_range(0.06, 0.12)
	visual.color = Color.from_hsv(hue, 0.9, 1.0)
	
	spark.add_child(visual)
	add_child(spark)
	_sparks.append(spark)

func _clear_sparks() -> void:
	for spark in _sparks:
		if is_instance_valid(spark):
			spark.queue_free()
	_sparks.clear()
