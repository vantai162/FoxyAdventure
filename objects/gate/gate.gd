# Gate.gd - Lever-controlled gate with vertical or horizontal movement
extends Node2D
class_name Gate

## Gate orientation - vertical moves up, horizontal moves left/right
enum GateDirection { VERTICAL, HORIZONTAL_LEFT, HORIZONTAL_RIGHT }

@export var direction: GateDirection = GateDirection.VERTICAL
@export var move_distance: float = 160.0  ## How far gate moves when opening
@export var open_duration: float = 1.0  ## Animation duration

var is_open: bool = false
var _tween: Tween

@onready var gate_body: AnimatableBody2D = $Gate if has_node("Gate") else null

func _ready() -> void:
	pass

func open_gate() -> void:
	if is_open:
		return
	is_open = true
	
	# Try animation player first (legacy support)
	if has_node("AnimationPlayer"):
		var anim_name = _get_open_animation_name()
		if $AnimationPlayer.has_animation(anim_name):
			$AnimationPlayer.play(anim_name)
			return
	
	# Fallback to tween-based movement
	_animate_gate(_get_open_offset())

func close_gate() -> void:
	if not is_open:
		return
	is_open = false
	
	# Try animation player (legacy support)
	if has_node("AnimationPlayer"):
		var anim_name = _get_close_animation_name()
		if $AnimationPlayer.has_animation(anim_name):
			$AnimationPlayer.play(anim_name)
			return
	
	# Fallback to tween-based movement
	_animate_gate(Vector2.ZERO)

func _get_open_offset() -> Vector2:
	match direction:
		GateDirection.VERTICAL:
			return Vector2(0, -move_distance)
		GateDirection.HORIZONTAL_LEFT:
			return Vector2(-move_distance, 0)
		GateDirection.HORIZONTAL_RIGHT:
			return Vector2(move_distance, 0)
	return Vector2.ZERO

func _get_open_animation_name() -> String:
	match direction:
		GateDirection.VERTICAL:
			return "open"
		GateDirection.HORIZONTAL_LEFT:
			return "open_left"
		GateDirection.HORIZONTAL_RIGHT:
			return "open_right"
	return "open"

func _get_close_animation_name() -> String:
	match direction:
		GateDirection.VERTICAL:
			return "close"
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
