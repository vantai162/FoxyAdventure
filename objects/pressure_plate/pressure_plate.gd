# Pressure Plate - Activates while player/object stands on it
extends Area2D
class_name PressurePlate

## What the plate controls (legacy - use channel for new designs)
enum PlateTarget { SIGNAL_ONLY, GATE, LAVA_LEVEL, FLAME, WATER_LEVEL }

@export_group("Channel System")
## Channel to broadcast on when pressed/released
## Set same channel on receiver objects (Gate, Flame, etc.) to connect them
@export var channel: StringName = &""

@export_group("Plate Settings")
## Legacy target type - prefer using channel system for new designs
@export var target_type: PlateTarget = PlateTarget.SIGNAL_ONLY
@export var stay_activated: bool = false  ## If true, stays ON after first press
@export var require_weight: bool = false  ## If true, only heavy objects trigger (not player)

@export_group("Visual Feedback")
@export var pressed_offset: Vector2 = Vector2(0, 2)  ## How much plate sinks when pressed
@export var press_duration: float = 0.1  ## Animation time

@export_group("Gate Control")
@export var gate_node: NodePath

@export_group("Lava Control")
@export var lava_node: NodePath
@export var lava_drain_time: float = 2.0
@export var lava_fill_time: float = 3.0

@export_group("Flame Control")
@export var flame_node: NodePath

@export_group("Water Control")
@export var water_node: NodePath
@export var water_on_level: float = -50.0
@export var water_off_level: float = 50.0
@export var water_transition_time: float = 2.0

signal plate_pressed
signal plate_released

var is_pressed: bool = false
var _bodies_on_plate: Array = []
var _permanently_activated: bool = false

var _gate_ref: Node = null
var _lava_ref: Node = null
var _flame_ref: Node = null
var _water_ref: Node = null

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var pressure_glow: PointLight2D = $Sprite2D/PressureGlow if has_node("Sprite2D/PressureGlow") else null
var _original_sprite_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# Cache node references
	if not gate_node.is_empty():
		_gate_ref = get_node_or_null(gate_node)
	if not lava_node.is_empty():
		_lava_ref = get_node_or_null(lava_node)
	if not flame_node.is_empty():
		_flame_ref = get_node_or_null(flame_node)
	if not water_node.is_empty():
		_water_ref = get_node_or_null(water_node)
	
	# Store original sprite position for tween animation
	if sprite:
		_original_sprite_pos = sprite.position
	else:
		# Fallback: create visual if none exists
		var plate_visual = get_node_or_null("Sprite2D")
		if plate_visual:
			sprite = plate_visual
			_original_sprite_pos = sprite.position

func _on_body_entered(body: Node2D) -> void:
	# Filter by weight requirement
	if require_weight:
		if body.is_in_group("heavy") or body.is_in_group("pushable"):
			pass  # Allow heavy objects
		else:
			return  # Ignore player and light objects
	else:
		# Accept player and interactable objects
		if not (body is Player or body.is_in_group("pushable")):
			return
	
	if not _bodies_on_plate.has(body):
		_bodies_on_plate.append(body)
	
	if not is_pressed and not _permanently_activated:
		_press()

func _on_body_exited(body: Node2D) -> void:
	_bodies_on_plate.erase(body)
	
	# Clean up invalid references
	var valid_bodies: Array = []
	for b in _bodies_on_plate:
		if is_instance_valid(b):
			valid_bodies.append(b)
	_bodies_on_plate = valid_bodies
	
	if is_pressed and _bodies_on_plate.is_empty() and not stay_activated:
		_release()

func _press() -> void:
	if _permanently_activated:
		return
	
	is_pressed = true
	plate_pressed.emit()
	
	# Broadcast on channel
	if not channel.is_empty():
		var channel_manager = get_node_or_null("/root/InteractionChannel")
		if channel_manager:
			channel_manager.activate(channel, self)
	
	# Visual feedback - tween position and enable glow
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "position", _original_sprite_pos + pressed_offset, press_duration)
		if pressure_glow:
			pressure_glow.enabled = true
			tween.tween_property(pressure_glow, "energy", 0.8, press_duration)
	
	# Trigger target (legacy)
	_on_plate_pressed()
	
	if stay_activated:
		_permanently_activated = true

func _release() -> void:
	is_pressed = false
	plate_released.emit()
	
	# Broadcast on channel
	if not channel.is_empty():
		var channel_manager = get_node_or_null("/root/InteractionChannel")
		if channel_manager:
			channel_manager.deactivate(channel, self)
	
	# Visual feedback - tween position back and fade glow
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "position", _original_sprite_pos, press_duration)
		if pressure_glow:
			tween.tween_property(pressure_glow, "energy", 0.0, press_duration)
			tween.finished.connect(func(): 
				if pressure_glow:
					pressure_glow.enabled = false
			)
	
	# Release target (legacy)
	_on_plate_released()

func _on_plate_pressed() -> void:
	match target_type:
		PlateTarget.GATE:
			if _gate_ref and _gate_ref.has_method("open_gate"):
				_gate_ref.open_gate()
		PlateTarget.LAVA_LEVEL:
			if _lava_ref and _lava_ref.has_method("drain"):
				_lava_ref.drain(lava_drain_time)
		PlateTarget.FLAME:
			if _flame_ref and _flame_ref.has_method("extinguish"):
				_flame_ref.extinguish()
		PlateTarget.WATER_LEVEL:
			if _water_ref and _water_ref.has_method("raise_water"):
				_water_ref.raise_water(water_on_level, water_transition_time)

func _on_plate_released() -> void:
	match target_type:
		PlateTarget.GATE:
			if _gate_ref and _gate_ref.has_method("close_gate"):
				_gate_ref.close_gate()
		PlateTarget.LAVA_LEVEL:
			if _lava_ref and _lava_ref.has_method("fill"):
				_lava_ref.fill(lava_fill_time)
		PlateTarget.FLAME:
			if _flame_ref and _flame_ref.has_method("ignite"):
				_flame_ref.ignite()
		PlateTarget.WATER_LEVEL:
			if _water_ref and _water_ref.has_method("lower_water"):
				_water_ref.lower_water(water_off_level, water_transition_time)

## Force plate state (for scripted events)
func force_press() -> void:
	if not is_pressed:
		_press()

func force_release() -> void:
	if is_pressed and not stay_activated:
		_release()

func reset() -> void:
	## Reset plate including permanent activation
	_permanently_activated = false
	_bodies_on_plate.clear()
	if is_pressed:
		_release()


## Blade projectile detection (Area2D-to-Area2D)
func _on_area_entered(area: Area2D) -> void:
	# Check if it's a grounded blade projectile
	if area is BladeProjectile:
		var blade := area as BladeProjectile
		# Only trigger if blade is grounded (not flying through)
		if blade.current_state == BladeProjectile.State.GROUNDED:
			if not _bodies_on_plate.has(blade):
				_bodies_on_plate.append(blade)
			if not is_pressed and not _permanently_activated:
				_press()


func _on_area_exited(area: Area2D) -> void:
	if area is BladeProjectile:
		_bodies_on_plate.erase(area)
		
		if is_pressed and _bodies_on_plate.is_empty() and not stay_activated:
			_release()
