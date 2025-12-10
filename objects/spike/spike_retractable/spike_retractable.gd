@tool
extends Node2D
class_name SpikeRetractable
## Retractable spike hazard with multiple trigger modes
## Use in rhythm platforming or trap setups
## 
## @tool script - orientation updates immediately in editor

## Visual orientation (which way the spike points)
enum Orientation {
	FLOOR,    ## Spike pointing up (default)
	CEILING,  ## Spike pointing down
	LEFT,     ## Spike pointing left
	RIGHT     ## Spike pointing right
}

## Trigger modes for different gameplay patterns
enum TriggerMode {
	INTERVAL,        ## Cycles forever on timer (default, rhythm platforming)
	PRESSURE_PLATE,  ## Extends when player steps on detection area
	MANUAL           ## Only via trigger_extend()/trigger_retract() calls
}

const ROTATIONS := {
	Orientation.FLOOR: 0.0,
	Orientation.CEILING: PI,
	Orientation.LEFT: PI / 2,
	Orientation.RIGHT: -PI / 2
}

@export var orientation := Orientation.FLOOR:
	set(value):
		orientation = value
		_apply_orientation()

@export_group("Trigger Mode")
@export var trigger_mode: TriggerMode = TriggerMode.INTERVAL
@export var detection_radius: float = 32.0  ## For PRESSURE_PLATE mode

@export_group("Positions")
@export var up_pos: Vector2 = Vector2(0, 0)  ## Extended position (dangerous)
@export var down_pos: Vector2 = Vector2(0, 20)  ## Retracted position (safe)

@export_group("Timing")
@export var up_time: float = 0.3  ## Time to extend
@export var down_time: float = 0.3  ## Time to retract
@export var hold_time: float = 1.0  ## Time to hold at each position (INTERVAL mode)
@export var pressure_delay: float = 0.15  ## Delay before extending (PRESSURE_PLATE)
@export var pressure_retract_delay: float = 0.5  ## Delay before retracting after player leaves

@export_group("Initial State")
@export var start_extended: bool = true  ## Start in up (dangerous) position
@export var start_delay: float = 0.0  ## Delay before first cycle (for staggering)

var is_extended: bool = false
var _detection_area: Area2D = null
var _player_on_plate: bool = false
var _current_tween: Tween = null

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _apply_orientation() -> void:
	if not is_inside_tree():
		return
	if sprite:
		sprite.rotation = ROTATIONS.get(orientation, 0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		call_deferred("_apply_orientation")

func _ready() -> void:
	_apply_orientation()
	
	# Don't run gameplay logic in editor
	if Engine.is_editor_hint():
		return
	
	# Set initial position
	position = up_pos if start_extended else down_pos
	is_extended = start_extended
	
	match trigger_mode:
		TriggerMode.INTERVAL:
			_start_interval_mode()
		TriggerMode.PRESSURE_PLATE:
			_setup_pressure_plate()
		TriggerMode.MANUAL:
			pass  # Wait for external calls

func _start_interval_mode() -> void:
	# Apply start delay if set
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	active()

func _setup_pressure_plate() -> void:
	# Create detection area for pressure plate mode
	_detection_area = Area2D.new()
	_detection_area.name = "PressureDetection"
	_detection_area.collision_layer = 0
	_detection_area.collision_mask = 2  # Player layer
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	collision.shape = shape
	# Position detection area at the spike base (down position)
	collision.position = down_pos
	
	_detection_area.add_child(collision)
	add_child(_detection_area)
	
	_detection_area.body_entered.connect(_on_pressure_body_entered)
	_detection_area.body_exited.connect(_on_pressure_body_exited)
	
	# Start retracted for pressure plate mode
	position = down_pos
	is_extended = false

func _on_pressure_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	_player_on_plate = true
	
	# Cancel any pending retraction
	if _current_tween:
		_current_tween.kill()
	
	# Delay then extend
	await get_tree().create_timer(pressure_delay).timeout
	
	if _player_on_plate:  # Still on plate
		trigger_extend()

func _on_pressure_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	_player_on_plate = false
	
	# Delay then retract
	await get_tree().create_timer(pressure_retract_delay).timeout
	
	if not _player_on_plate:  # Still off plate
		trigger_retract()

func active() -> void:
	## INTERVAL mode: continuous cycle
	if _current_tween:
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.tween_property(self, "position", up_pos, up_time)
	_current_tween.tween_callback(func(): is_extended = true)
	_current_tween.tween_interval(hold_time)
	_current_tween.tween_property(self, "position", down_pos, down_time)
	_current_tween.tween_callback(func(): is_extended = false)
	_current_tween.tween_interval(hold_time)
	_current_tween.finished.connect(active)

## Manual control methods

func trigger_extend() -> void:
	## Extend spike (make dangerous)
	if is_extended:
		return
	
	if _current_tween:
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.tween_property(self, "position", up_pos, up_time)
	_current_tween.tween_callback(func(): is_extended = true)

func trigger_retract() -> void:
	## Retract spike (make safe)
	if not is_extended:
		return
	
	if _current_tween:
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.tween_property(self, "position", down_pos, down_time)
	_current_tween.tween_callback(func(): is_extended = false)

## Pause the spike cycle (INTERVAL mode only)
func pause() -> void:
	if _current_tween:
		_current_tween.pause()

## Resume the spike cycle  
func resume() -> void:
	if _current_tween:
		_current_tween.play()

## Force spike to extended position immediately
func force_extended() -> void:
	if _current_tween:
		_current_tween.kill()
	position = up_pos
	is_extended = true

## Force spike to retracted position immediately
func force_retracted() -> void:
	if _current_tween:
		_current_tween.kill()
	position = down_pos
	is_extended = false
