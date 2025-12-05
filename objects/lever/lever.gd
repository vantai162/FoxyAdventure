# Lever - Interactive switch for gates, water levels, and custom actions
extends Area2D
class_name Lever

## What the lever controls
enum LeverTarget { SIGNAL_ONLY, WATER_LEVEL, GATE }

@export_group("Lever Settings")
@export var is_activated: bool = false
@export var target_type: LeverTarget = LeverTarget.SIGNAL_ONLY

@export_group("Water Control")
@export var water_node: NodePath  ## Path to water node to control
@export var water_on_level: float = -50.0  ## surface_pos_y when ON (negative = higher)
@export var water_off_level: float = 50.0  ## surface_pos_y when OFF (positive = lower)
@export var water_transition_time: float = 2.0

@export_group("Gate Control")
@export var gate_node: NodePath  ## Path to gate node to control

signal lever_activated
signal lever_deactivated

var player_is_near: bool = false
var _water_ref: Node = null
var _gate_ref: Node = null

func _ready() -> void:
	update_animation()
	
	# Cache node references
	if not water_node.is_empty():
		_water_ref = get_node_or_null(water_node)
	if not gate_node.is_empty():
		_gate_ref = get_node_or_null(gate_node)

func _process(_delta: float) -> void:
	if player_is_near and Input.is_action_just_pressed("interact"):
		activate()

func activate() -> void:
	is_activated = not is_activated
	update_animation()

	if is_activated:
		lever_activated.emit()
		_on_lever_on()
	else:
		lever_deactivated.emit()
		_on_lever_off()

func _on_lever_on() -> void:
	match target_type:
		LeverTarget.WATER_LEVEL:
			if _water_ref and _water_ref.has_method("raise_water"):
				_water_ref.raise_water(water_on_level, water_transition_time)
		LeverTarget.GATE:
			if _gate_ref and _gate_ref.has_method("open_gate"):
				_gate_ref.open_gate()

func _on_lever_off() -> void:
	match target_type:
		LeverTarget.WATER_LEVEL:
			if _water_ref and _water_ref.has_method("lower_water"):
				_water_ref.lower_water(water_off_level, water_transition_time)
		LeverTarget.GATE:
			if _gate_ref and _gate_ref.has_method("close_gate"):
				_gate_ref.close_gate()

func update_animation() -> void:
	if has_node("AnimatedSprite2D"):
		if is_activated:
			$AnimatedSprite2D.play("on")
		else:
			$AnimatedSprite2D.play("off")

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_is_near = true
	
func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_is_near = false

## Force lever state (for scripted events)
func set_state(activated: bool) -> void:
	if is_activated != activated:
		activate()
