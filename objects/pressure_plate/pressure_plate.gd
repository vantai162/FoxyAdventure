@tool
# Pressure Plate - Activates while player/object stands on it
# Uses Channel System: set a channel name, receivers (Gate, Flame, etc.) listen on the same channel
extends Area2D
class_name PressurePlate

@export_group("Channel System")
## Channel to broadcast on when pressed/released
## Set same channel on receiver objects (Gate, Flame, etc.) to connect them
@export var channel: StringName = &"":
	set(value):
		channel = value
		queue_redraw()

@export_group("Plate Settings")
@export var stay_activated: bool = false  ## If true, stays ON after first press
@export var require_weight: bool = false  ## If true, only heavy objects trigger (not player)

@export_group("Visual Feedback")
@export var pressed_offset: Vector2 = Vector2(0, 2)  ## How much plate sinks when pressed
@export var press_duration: float = 0.1  ## Animation time

@export_group("Editor Preview")
@export var show_channel_label: bool = true:
	set(value):
		show_channel_label = value
		queue_redraw()
@export var label_color: Color = Color(0.2, 0.9, 0.4, 0.9)

signal plate_pressed
signal plate_released

var is_pressed: bool = false
var _bodies_on_plate: Array = []
var _permanently_activated: bool = false

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var pressure_glow: PointLight2D = $Sprite2D/PressureGlow if has_node("Sprite2D/PressureGlow") else null
var _original_sprite_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Skip gameplay in editor
	if Engine.is_editor_hint():
		return
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# Listen for scene tree changes to clean up stale body references
	# This handles player death/respawn where body is freed without exiting
	get_tree().node_removed.connect(_on_any_node_removed)
	
	# Store original sprite position for tween animation
	if sprite:
		_original_sprite_pos = sprite.position
	else:
		# Fallback: create visual if none exists
		var plate_visual = get_node_or_null("Sprite2D")
		if plate_visual:
			sprite = plate_visual
			_original_sprite_pos = sprite.position


func _exit_tree() -> void:
	# Clean up global signal connection when plate is removed
	if Engine.is_editor_hint():
		return
	
	if get_tree() and get_tree().node_removed.is_connected(_on_any_node_removed):
		get_tree().node_removed.disconnect(_on_any_node_removed)


func _on_any_node_removed(node: Node) -> void:
	## Called when ANY node is removed from tree - check if it was on the plate
	## This handles the case where a body is queue_free'd (e.g., player death)
	## without triggering body_exited
	if _bodies_on_plate.has(node):
		_bodies_on_plate.erase(node)
		
		# If plate is now empty and was pressed, release it
		if is_pressed and _bodies_on_plate.is_empty() and not stay_activated and not _permanently_activated:
			_release()

## Editor draw - show channel label
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if not show_channel_label or channel.is_empty():
		return
	
	# Draw channel name label above the plate
	var font := ThemeDB.fallback_font
	var label_text := str(channel)
	var font_size := 12
	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var label_pos := Vector2(-text_size.x / 2, -24)
	
	# Background for readability
	var bg_rect := Rect2(label_pos - Vector2(4, font_size), text_size + Vector2(8, 4))
	draw_rect(bg_rect, Color(0.1, 0.1, 0.1, 0.7))
	
	# Draw text
	draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, label_color)
	
	# Draw indicator icon (P for Plate)
	draw_circle(Vector2(0, -32), 8, label_color * Color(1, 1, 1, 0.6))

func _on_body_entered(body: Node2D) -> void:
	# Filter by weight requirement
	if require_weight:
		# Only heavy/pushable objects trigger
		if not (body.is_in_group("heavy") or body.is_in_group("pushable")):
			return
	else:
		AudioManager.play_sound("button_press",10.0)
		# Accept: player, enemies, and pushable objects
		# This allows puzzle design where enemies can trigger plates!
		var is_valid := false
		if body is Player:
			is_valid = true
		elif body.is_in_group("enemy"):
			is_valid = true
		elif body.is_in_group("pushable"):
			is_valid = true
		
		if not is_valid:
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
