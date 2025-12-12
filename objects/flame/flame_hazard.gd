@tool
extends Node2D
class_name FlameHazard

## Cycling flame hazard that also emits light
## NOW GPU-ACCELERATED - zero CPU particle overhead
## Can be used both as a hazard and a light source in dark areas
##
## SETUP: Scene includes FlameLight PointLight2D and SparkParticles GPUParticles2D
## Configure in the editor. Script handles on/off cycling and flicker animation.
##
## CHANNEL SYSTEM: Set listen_channel to connect to Lever/PressurePlate

enum Orientation {
	FLOOR,    ## Flame shooting up (default)
	CEILING,  ## Flame shooting down
	LEFT,     ## Flame shooting left
	RIGHT     ## Flame shooting right
}

## What to do when channel is activated/deactivated
enum FlameAction { IGNITE, EXTINGUISH, TOGGLE }

@export var orientation := Orientation.FLOOR:
	set(value):
		orientation = value
		_apply_orientation()

@export_group("Channel System")
## Channel to listen to for flame control
## Set same channel on trigger objects (Lever, PressurePlate) to connect them
@export var listen_channel: StringName = &""
## What to do when channel activates (lever pulled, plate pressed)
@export var on_activate: FlameAction = FlameAction.EXTINGUISH
## What to do when channel deactivates (lever unpulled, plate released)
@export var on_deactivate: FlameAction = FlameAction.IGNITE

@export_group("Flame Settings")
@export var cycle_enabled: bool = true  ## If false, flame stays on permanently
@export var on_duration: float = 2.0  ## How long flame stays active
@export var off_duration: float = 1.5  ## How long flame stays off

@export_group("Damage")
@export var damage: int = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area_1: Area2D = $HitArea2D
@onready var hit_area_2: Area2D = $HitArea2D2
@onready var flame_light: PointLight2D = $FlameLight
@onready var spark_particles: GPUParticles2D = $SparkParticles

var is_active: bool = false
var current_phase: String = "off"
var _base_energy: float = 0.8
var _base_color: Color = Color(1.0, 0.7, 0.3, 1.0)
var _flicker_tween: Tween

# Rotation angles for each orientation
const ROTATIONS := {
	Orientation.FLOOR: 0.0,
	Orientation.CEILING: PI,
	Orientation.LEFT: PI / 2,
	Orientation.RIGHT: -PI / 2
}

func _apply_orientation() -> void:
	if not is_inside_tree():
		return
	rotation = ROTATIONS.get(orientation, 0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		call_deferred("_apply_orientation")

func _ready() -> void:
	_apply_orientation()
	
	# Don't run gameplay logic in editor
	if Engine.is_editor_hint():
		return
	# Setup collisions as disabled initially
	_set_collision_enabled(false)
	
	# Capture base values from scene-configured light
	if flame_light:
		_base_energy = flame_light.energy
		_base_color = flame_light.color
		flame_light.energy = 0  # Start off
		if flame_light.texture == null:
			_setup_light_texture()
	
	# Setup GPU particles
	if spark_particles:
		_setup_spark_particles()
	
	# Subscribe to channel system
	if not listen_channel.is_empty():
		InteractionChannel.channel_activated.connect(_on_channel_activated)
		InteractionChannel.channel_deactivated.connect(_on_channel_deactivated)
	
	# Start the cycle
	if cycle_enabled:
		play_cycle()
	else:
		# Permanent flame
		await start_phase()
		await active_phase_loop()


func _on_channel_activated(channel: StringName, _source: Node) -> void:
	if channel != listen_channel:
		return
	_execute_flame_action(on_activate)


func _on_channel_deactivated(channel: StringName, _source: Node) -> void:
	if channel != listen_channel:
		return
	_execute_flame_action(on_deactivate)


func _execute_flame_action(action: FlameAction) -> void:
	match action:
		FlameAction.IGNITE:
			ignite()
		FlameAction.EXTINGUISH:
			extinguish()
		FlameAction.TOGGLE:
			if is_active:
				extinguish()
			else:
				ignite()

func _setup_light_texture() -> void:
	## Smooth gradient for flame glow
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

func _setup_spark_particles() -> void:
	## Configure GPU particle material for sparks
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(20, 8, 0)
	mat.direction = Vector3(0, -1, 0)  # Upward (Y- in Godot)
	mat.spread = 30.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0, 15, 0)  # Gravity pulls down (Y+ is down!)
	mat.damping_min = 8.0  # Air resistance
	mat.damping_max = 12.0
	mat.scale_min = 1.5
	mat.scale_max = 2.5
	
	# Fade out curve
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0, 1))
	alpha_curve.add_point(Vector2(0.7, 0.7))
	alpha_curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = alpha_curve
	mat.alpha_curve = curve_tex
	
	# Use GradientTexture1D for color_ramp (like whirlpool)
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.8, 0.4))
	grad.add_point(0.7, Color(1.0, 0.4, 0.1, 0.5))
	grad.add_point(1.0, Color.TRANSPARENT)
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = grad
	mat.color_ramp = gradient_texture
	
	spark_particles.process_material = mat
	
	add_child(spark_particles)

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
	
	# Enable GPU particles
	if spark_particles:
		spark_particles.emitting = true
	
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
	
	if spark_particles:
		spark_particles.emitting = true
	
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
	
	# Disable GPU particles
	if spark_particles:
		spark_particles.emitting = false
	
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
		if hit_area_2.has_node("CollisionShape2D"):
			hit_area_2.get_node("CollisionShape2D").disabled = not enabled

func _start_flicker() -> void:
	if flame_light == null:
		return
	
	if _flicker_tween:
		_flicker_tween.kill()
	
	_flicker_tween = create_tween().set_loops()
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
