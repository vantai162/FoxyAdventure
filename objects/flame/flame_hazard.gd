extends Node2D
class_name FlameHazard

## Cycling flame hazard that also emits light
## Can be used both as a hazard and a light source in dark areas

@export_group("Flame Settings")
@export var cycle_enabled: bool = true  ## If false, flame stays on permanently
@export var on_duration: float = 2.0  ## How long flame stays active
@export var off_duration: float = 1.5  ## How long flame stays off

@export_group("Light Settings")
@export var emit_light: bool = true  ## Whether this flame produces light
@export var light_radius: float = 150.0  ## Light radius when active
@export var light_color: Color = Color(1.0, 0.7, 0.3, 1.0)  ## Warm orange
@export var light_energy: float = 0.8

@export_group("Damage")
@export var damage: int = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area_1: Area2D = $HitArea2D
@onready var hit_area_2: Area2D = $HitArea2D2

var flame_light: PointLight2D
var is_active: bool = false
var current_phase: String = "off"

func _ready() -> void:
	# Setup collisions as disabled initially
	_set_collision_enabled(false)
	
	# Create light if enabled
	if emit_light:
		_create_light()
	
	# Start the cycle
	if cycle_enabled:
		play_cycle()
	else:
		# Permanent flame
		await start_phase()
		await active_phase_loop()

func _create_light() -> void:
	flame_light = PointLight2D.new()
	flame_light.name = "FlameLight"
	flame_light.color = light_color
	flame_light.energy = 0  # Start off
	flame_light.texture_scale = light_radius / 512.0
	flame_light.position = Vector2(-20, 0)  # Center on flame
	
	# Create gradient texture for soft falloff
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
	add_child(flame_light)

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
		tween.tween_property(flame_light, "energy", light_energy, 0.3)
	
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
		flame_light.energy = light_energy
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
	_flicker_tween.tween_property(flame_light, "energy", light_energy * 1.1, 0.1)
	_flicker_tween.tween_property(flame_light, "energy", light_energy * 0.9, 0.15)
	_flicker_tween.tween_property(flame_light, "energy", light_energy, 0.1)

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
