@tool
extends Node2D
class_name SpikeRetractable
## Retractable spike hazard with multiple trigger modes
## 
## Architecture:
## - Root node (this) stays stationary - detection area is here
## - SpikeBody child moves up/down - contains sprite and hitbox
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
	MANUAL,          ## Only via trigger_extend()/trigger_retract() calls
	CHANNEL          ## Controlled by InteractionChannel (lever, pressure plate, etc.)
}

## What to do when channel is activated
enum ChannelAction { EXTEND, RETRACT, TOGGLE }

const ROTATIONS := {
	Orientation.FLOOR: 0.0,
	Orientation.CEILING: PI,
	Orientation.LEFT: PI / 2,
	Orientation.RIGHT: -PI / 2
}

## Retract directions for each orientation (where the spike hides)
const RETRACT_DIRECTIONS := {
	Orientation.FLOOR: Vector2(0, 1),     ## Retracts down into floor
	Orientation.CEILING: Vector2(0, -1),  ## Retracts up into ceiling
	Orientation.LEFT: Vector2(1, 0),      ## Retracts right into left wall
	Orientation.RIGHT: Vector2(-1, 0)     ## Retracts left into right wall
}

@export var orientation := Orientation.FLOOR:
	set(value):
		orientation = value
		_apply_orientation()

@export_group("Trigger Mode")
@export var trigger_mode: TriggerMode = TriggerMode.INTERVAL

@export_group("Channel System")
## Channel to listen to (only used when trigger_mode = CHANNEL)
@export var listen_channel: StringName = &""
## What to do when channel activates
@export var on_activate: ChannelAction = ChannelAction.EXTEND
## What to do when channel deactivates
@export var on_deactivate: ChannelAction = ChannelAction.RETRACT

@export_group("Positions")
## How far the spike retracts (in pixels)
@export var retract_distance: float = 20.0

@export_group("Timing")
@export var up_time: float = 0.3
@export var down_time: float = 0.3
@export var hold_time: float = 1.0
@export var pressure_delay: float = 0.15
@export var pressure_retract_delay: float = 0.5

@export_group("Initial State")
@export var start_extended: bool = true
@export var start_delay: float = 0.0

var is_extended: bool = false
var _player_on_plate: bool = false
var _current_tween: Tween = null

# The moving part (sprite + hitbox)
@onready var _spike_body: Node2D = $SpikeBody
# Detection stays with root (doesn't move)
@onready var _pressure_detection: Area2D = $PressureDetection
# Sprite is now under SpikeBody
@onready var _sprite: Sprite2D = $SpikeBody/Sprite2D if has_node("SpikeBody/Sprite2D") else null

func _apply_orientation() -> void:
	if not is_inside_tree():
		return
	# Rotate the ENTIRE spike body (sprite + hitbox together)
	var spike_body = get_node_or_null("SpikeBody")
	if spike_body:
		spike_body.rotation = ROTATIONS.get(orientation, 0.0)

## Get extended position (spike is OUT and dangerous)
func _get_extended_pos() -> Vector2:
	return Vector2.ZERO

## Get retracted position (spike is hidden)
func _get_retracted_pos() -> Vector2:
	return RETRACT_DIRECTIONS.get(orientation, Vector2(0, 1)) * retract_distance

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		call_deferred("_apply_orientation")

func _ready() -> void:
	_apply_orientation()
	
	if Engine.is_editor_hint():
		return
	
	# Disable pressure detection by default
	if _pressure_detection:
		_pressure_detection.monitoring = false
		_pressure_detection.monitorable = false
	
	# Set initial position of the SPIKE BODY (not self!)
	if _spike_body:
		_spike_body.position = _get_extended_pos() if start_extended else _get_retracted_pos()
	is_extended = start_extended
	
	match trigger_mode:
		TriggerMode.INTERVAL:
			_start_interval_mode()
		TriggerMode.PRESSURE_PLATE:
			_setup_pressure_plate()
		TriggerMode.CHANNEL:
			_setup_channel_mode()
		TriggerMode.MANUAL:
			pass

func _setup_channel_mode() -> void:
	if listen_channel.is_empty():
		push_warning("SpikeRetractable: CHANNEL mode but no listen_channel set")
		return
	
	InteractionChannel.channel_activated.connect(_on_channel_activated)
	InteractionChannel.channel_deactivated.connect(_on_channel_deactivated)

func _on_channel_activated(channel: StringName, _source: Node) -> void:
	if channel != listen_channel:
		return
	
	match on_activate:
		ChannelAction.EXTEND:
			trigger_extend()
		ChannelAction.RETRACT:
			trigger_retract()
		ChannelAction.TOGGLE:
			if is_extended:
				trigger_retract()
			else:
				trigger_extend()

func _on_channel_deactivated(channel: StringName, _source: Node) -> void:
	if channel != listen_channel:
		return
	
	match on_deactivate:
		ChannelAction.EXTEND:
			trigger_extend()
		ChannelAction.RETRACT:
			trigger_retract()
		ChannelAction.TOGGLE:
			if is_extended:
				trigger_retract()
			else:
				trigger_extend()

func _start_interval_mode() -> void:
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	_run_cycle()

func _run_cycle() -> void:
	if not _spike_body:
		return
	
	if _current_tween:
		_current_tween.kill()
	
	var extended_pos := _get_extended_pos()
	var retracted_pos := _get_retracted_pos()
	
	_current_tween = create_tween()
	_current_tween.tween_property(_spike_body, "position", extended_pos, up_time)
	_current_tween.tween_callback(func(): is_extended = true)
	_current_tween.tween_interval(hold_time)
	_current_tween.tween_property(_spike_body, "position", retracted_pos, down_time)
	_current_tween.tween_callback(func(): is_extended = false)
	_current_tween.tween_interval(hold_time)
	_current_tween.finished.connect(_run_cycle)

func _setup_pressure_plate() -> void:
	if not _pressure_detection:
		push_warning("SpikeRetractable: PressureDetection node missing")
		return
	if not _spike_body:
		push_warning("SpikeRetractable: SpikeBody node missing")
		return
	
	# Enable detection - it's already at the right position (child of root)
	_pressure_detection.monitoring = true
	_pressure_detection.monitorable = true
	
	_pressure_detection.body_entered.connect(_on_pressure_body_entered)
	_pressure_detection.body_exited.connect(_on_pressure_body_exited)
	
	# Start retracted
	_spike_body.position = _get_retracted_pos()
	is_extended = false

func _on_pressure_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	_player_on_plate = true
	
	if _current_tween:
		_current_tween.kill()
	
	if pressure_delay > 0.0:
		await get_tree().create_timer(pressure_delay).timeout
	
	trigger_extend()

func _on_pressure_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	_player_on_plate = false
	
	await get_tree().create_timer(pressure_retract_delay).timeout
	
	if not _player_on_plate:
		trigger_retract()

func trigger_extend() -> void:
	if is_extended or not _spike_body:
		return
	
	if _current_tween:
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.tween_property(_spike_body, "position", _get_extended_pos(), up_time)
	_current_tween.tween_callback(func(): is_extended = true)

func trigger_retract() -> void:
	if not is_extended or not _spike_body:
		return
	
	if _current_tween:
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.tween_property(_spike_body, "position", _get_retracted_pos(), down_time)
	_current_tween.tween_callback(func(): is_extended = false)

func pause() -> void:
	if _current_tween:
		_current_tween.pause()

func resume() -> void:
	if _current_tween:
		_current_tween.play()

func force_extended() -> void:
	if _current_tween:
		_current_tween.kill()
	if _spike_body:
		_spike_body.position = _get_extended_pos()
	is_extended = true

func force_retracted() -> void:
	if _current_tween:
		_current_tween.kill()
	if _spike_body:
		_spike_body.position = _get_retracted_pos()
	is_extended = false

# Legacy compatibility - keep active() as alias
func active() -> void:
	_run_cycle()
