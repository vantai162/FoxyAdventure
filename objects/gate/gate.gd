@tool
# Gate.gd - Lever-controlled gate with vertical or horizontal movement
extends Node2D
class_name Gate

## Gate direction - controls both visual orientation AND movement direction
## VERTICAL_UP: Gate is "|" shape, slides UP to open (floor gate)
## VERTICAL_DOWN: Gate is "|" shape, slides DOWN to open (ceiling gate)
## HORIZONTAL_LEFT: Gate is "—" shape, slides LEFT to open
## HORIZONTAL_RIGHT: Gate is "—" shape, slides RIGHT to open
enum GateDirection { VERTICAL_UP, VERTICAL_DOWN, HORIZONTAL_LEFT, HORIZONTAL_RIGHT }

## What to do when channel is activated
enum ChannelAction { OPEN, CLOSE, TOGGLE }

const ROTATIONS := {
	GateDirection.VERTICAL_UP: 0.0,
	GateDirection.VERTICAL_DOWN: 0.0,  # Same visual, different movement
	GateDirection.HORIZONTAL_LEFT: PI / 2,  # 90° - horizontal bar
	GateDirection.HORIZONTAL_RIGHT: PI / 2  # 90° - horizontal bar
}

@export_group("Channel System")
## Channel to listen to for activation
## Set same channel on trigger objects (Lever, PressurePlate) to connect them
@export var listen_channel: StringName = &""
## What to do when channel activates
@export var on_activate: ChannelAction = ChannelAction.OPEN
## What to do when channel deactivates (lever turned off, plate released)
@export var on_deactivate: ChannelAction = ChannelAction.CLOSE

@export_group("Gate Settings")
@export var direction: GateDirection = GateDirection.VERTICAL_UP:
	set(value):
		direction = value
		_apply_direction()

@export var move_distance: float = 160.0  ## How far gate moves when opening
@export var open_duration: float = 1.0  ## Animation duration

var is_open: bool = false
var _tween: Tween

@onready var gate_body: AnimatableBody2D = $Gate if has_node("Gate") else null

func _apply_direction() -> void:
	if not is_inside_tree():
		return
	if gate_body:
		gate_body.rotation = ROTATIONS.get(direction, 0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		call_deferred("_apply_direction")

func _ready() -> void:
	_apply_direction()
	
	# Don't run gameplay logic in editor
	if Engine.is_editor_hint():
		return
	
	# Subscribe to channel
	if not listen_channel.is_empty():
		var channel_manager = get_node_or_null("/root/InteractionChannel")
		if channel_manager:
			channel_manager.channel_activated.connect(_on_channel_activated)
			channel_manager.channel_deactivated.connect(_on_channel_deactivated)

func _on_channel_activated(channel: StringName, _source: Node) -> void:
	if channel != listen_channel:
		return
	
	match on_activate:
		ChannelAction.OPEN:
			open_gate()
		ChannelAction.CLOSE:
			close_gate()
		ChannelAction.TOGGLE:
			toggle_gate()

func _on_channel_deactivated(channel: StringName, _source: Node) -> void:
	if channel != listen_channel:
		return
	
	match on_deactivate:
		ChannelAction.OPEN:
			open_gate()
		ChannelAction.CLOSE:
			close_gate()
		ChannelAction.TOGGLE:
			toggle_gate()

func open_gate() -> void:
	if Engine.is_editor_hint():
		return
	if is_open:
		return
	is_open = true
	
	# Try animation player first (for custom animations)
	if has_node("AnimationPlayer"):
		var anim_name = _get_open_animation_name()
		if $AnimationPlayer.has_animation(anim_name):
			$AnimationPlayer.play(anim_name)
			return
	
	# Fallback to tween-based movement
	_animate_gate(_get_open_offset())

func close_gate() -> void:
	if Engine.is_editor_hint():
		return
	if not is_open:
		return
	is_open = false
	
	# Try animation player (for custom animations)
	if has_node("AnimationPlayer"):
		var anim_name = _get_close_animation_name()
		if $AnimationPlayer.has_animation(anim_name):
			$AnimationPlayer.play(anim_name)
			return
	
	# Fallback to tween-based movement
	_animate_gate(Vector2.ZERO)

func _get_open_offset() -> Vector2:
	## NOTE: gate_body IS rotated for horizontal orientations, but gate_body.position
	## is set in PARENT space (this Node2D), which is NOT rotated.
	## So world-space directions work correctly here - no rotation compensation needed.
	match direction:
		GateDirection.VERTICAL_UP:
			return Vector2(0, -move_distance)
		GateDirection.VERTICAL_DOWN:
			return Vector2(0, move_distance)
		GateDirection.HORIZONTAL_LEFT:
			return Vector2(-move_distance, 0)
		GateDirection.HORIZONTAL_RIGHT:
			return Vector2(move_distance, 0)
	return Vector2.ZERO

func _get_open_animation_name() -> String:
	match direction:
		GateDirection.VERTICAL_UP:
			return "open"
		GateDirection.VERTICAL_DOWN:
			return "open_down"
		GateDirection.HORIZONTAL_LEFT:
			return "open_left"
		GateDirection.HORIZONTAL_RIGHT:
			return "open_right"
	return "open"

func _get_close_animation_name() -> String:
	match direction:
		GateDirection.VERTICAL_UP:
			return "close"
		GateDirection.VERTICAL_DOWN:
			return "close_down"
		GateDirection.HORIZONTAL_LEFT:
			return "close_left"
		GateDirection.HORIZONTAL_RIGHT:
			return "close_right"
	return "close"

func _animate_gate(target_offset: Vector2) -> void:
	if not gate_body:
		return
	
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(gate_body, "position", target_offset, open_duration)

## Toggle gate state
func toggle_gate() -> void:
	if is_open:
		close_gate()
	else:
		open_gate()
