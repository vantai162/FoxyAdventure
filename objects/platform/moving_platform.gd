@tool
extends AnimatableBody2D
class_name MovingPlatform
## Designer-friendly moving platform with visual trajectory preview
##
## USAGE: 
## 1. Instance this scene in your level
## 2. Drag the EndPoint marker to set destination
## 3. Adjust speed and behavior in Inspector
## The trajectory line shows exactly where the platform will go!

enum MovementType {
	PING_PONG,    ## Moves back and forth between start and end
	ONE_WAY,      ## Moves to end and teleports back to start
	LOOP          ## Moves to end, then continues to start (circular)
}

enum EasingType {
	LINEAR,       ## Constant speed
	EASE_IN_OUT,  ## Smooth acceleration/deceleration
	EASE_IN,      ## Starts slow, ends fast
	EASE_OUT      ## Starts fast, ends slow
}

@export_group("Movement")
## How fast the platform moves (pixels per second)
@export var speed: float = 100.0
## Movement pattern
@export var movement_type: MovementType = MovementType.PING_PONG
## Easing for smooth movement
@export var easing: EasingType = EasingType.LINEAR
## Pause duration at each endpoint (seconds)
@export var pause_at_endpoints: float = 0.0
## Start moving automatically when scene loads
@export var auto_start: bool = true
## Start at the end position instead of start
@export var start_at_end: bool = false

@export_group("Editor Preview")
## Color of the trajectory line in editor
@export var trajectory_color: Color = Color(0.2, 0.8, 0.2, 0.8)
## Show trajectory line in editor
@export var show_trajectory: bool = true
## Thickness of trajectory line
@export var trajectory_width: float = 2.0

@export_group("Channel Integration")
## Channel to listen on for start/stop commands
@export var listen_channel: StringName = &""
## Start paused, wait for channel activation
@export var start_paused: bool = false

## The endpoint marker - drag this in the editor to set destination!
@onready var end_point: Marker2D = $EndPoint

var _start_position: Vector2
var _end_position: Vector2
var _progress: float = 0.0  # 0.0 = start, 1.0 = end
var _direction: int = 1  # 1 = toward end, -1 = toward start
var _is_paused: bool = false
var _pause_timer: float = 0.0
var _is_moving: bool = true
var _total_distance: float = 0.0

func _ready() -> void:
	# Store positions
	_start_position = global_position
	if end_point:
		_end_position = end_point.global_position
	else:
		_end_position = _start_position + Vector2(100, 0)  # Default fallback
	
	_total_distance = _start_position.distance_to(_end_position)
	
	# Handle start_at_end
	if start_at_end:
		_progress = 1.0
		_direction = -1
		global_position = _end_position
	
	# Handle start_paused
	if start_paused:
		_is_moving = false
	
	# Skip gameplay in editor
	if Engine.is_editor_hint():
		return
	
	# Hide endpoint marker at runtime (it's just for editing)
	if end_point:
		end_point.visible = false
	
	# Register for channel events
	if not listen_channel.is_empty():
		var channel_manager = get_node_or_null("/root/InteractionChannel")
		if channel_manager:
			channel_manager.register_listener(listen_channel, _on_channel_activated, _on_channel_deactivated)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if not listen_channel.is_empty():
		var channel_manager = get_node_or_null("/root/InteractionChannel")
		if channel_manager:
			channel_manager.unregister_listener(listen_channel, _on_channel_activated, _on_channel_deactivated)

func _on_channel_activated(_source: Node) -> void:
	_is_moving = true

func _on_channel_deactivated(_source: Node) -> void:
	_is_moving = false

func _physics_process(delta: float) -> void:
	# Editor: just update end position from marker
	if Engine.is_editor_hint():
		if end_point:
			_end_position = end_point.global_position
			_start_position = global_position
		queue_redraw()
		return
	
	# Handle pause at endpoints
	if _pause_timer > 0:
		_pause_timer -= delta
		return
	
	# Skip if paused or not moving
	if _is_paused or not _is_moving or not auto_start:
		return
	
	# Calculate movement
	if _total_distance <= 0:
		return
	
	var speed_normalized = speed / _total_distance
	_progress += speed_normalized * delta * _direction
	
	# Handle endpoints
	if _progress >= 1.0:
		_progress = 1.0
		_handle_reached_end()
	elif _progress <= 0.0:
		_progress = 0.0
		_handle_reached_start()
	
	# Apply eased position
	var eased_progress = _apply_easing(_progress)
	global_position = _start_position.lerp(_end_position, eased_progress)

func _apply_easing(t: float) -> float:
	match easing:
		EasingType.LINEAR:
			return t
		EasingType.EASE_IN_OUT:
			return t * t * (3.0 - 2.0 * t)  # Smoothstep
		EasingType.EASE_IN:
			return t * t
		EasingType.EASE_OUT:
			return 1.0 - (1.0 - t) * (1.0 - t)
	return t

func _handle_reached_end() -> void:
	match movement_type:
		MovementType.PING_PONG:
			_direction = -1
			if pause_at_endpoints > 0:
				_pause_timer = pause_at_endpoints
		MovementType.ONE_WAY:
			_progress = 0.0
			global_position = _start_position
			if pause_at_endpoints > 0:
				_pause_timer = pause_at_endpoints
		MovementType.LOOP:
			_progress = 0.0
			# No teleport - continues smoothly

func _handle_reached_start() -> void:
	match movement_type:
		MovementType.PING_PONG:
			_direction = 1
			if pause_at_endpoints > 0:
				_pause_timer = pause_at_endpoints
		MovementType.ONE_WAY:
			pass  # ONE_WAY only teleports at end, not start
		MovementType.LOOP:
			_progress = 1.0
			# Loop back to end

func _draw() -> void:
	# Only draw in editor
	if not Engine.is_editor_hint() or not show_trajectory:
		return
	
	if not end_point:
		return
	
	# Draw line from current position to endpoint
	var local_end = to_local(end_point.global_position)
	draw_line(Vector2.ZERO, local_end, trajectory_color, trajectory_width)
	
	# Draw endpoint circle
	draw_circle(local_end, 6.0, trajectory_color)
	
	# Draw start position indicator
	draw_circle(Vector2.ZERO, 4.0, trajectory_color.darkened(0.3))
	
	# Draw direction arrow
	var mid_point = local_end * 0.5
	var arrow_dir = local_end.normalized()
	var arrow_perp = arrow_dir.rotated(PI / 2)
	var arrow_size = 8.0
	draw_line(mid_point, mid_point - arrow_dir * arrow_size + arrow_perp * arrow_size * 0.5, trajectory_color, trajectory_width)
	draw_line(mid_point, mid_point - arrow_dir * arrow_size - arrow_perp * arrow_size * 0.5, trajectory_color, trajectory_width)

## API for external control
func start_moving() -> void:
	_is_moving = true
	auto_start = true

func stop_moving() -> void:
	_is_moving = false

func pause() -> void:
	_is_paused = true

func resume() -> void:
	_is_paused = false

func reset_to_start() -> void:
	_progress = 0.0
	_direction = 1
	global_position = _start_position

func reset_to_end() -> void:
	_progress = 1.0
	_direction = -1
	global_position = _end_position
