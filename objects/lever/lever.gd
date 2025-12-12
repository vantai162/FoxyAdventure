# Lever - Interactive switch for gates, water, lava, flames, and custom actions
# Supports both toggle mode (stays on/off) and timed mode (auto-resets after duration)
extends Area2D
class_name Lever

## What the lever controls (legacy - use channel for new designs)
enum LeverTarget { SIGNAL_ONLY, WATER_LEVEL, GATE, LAVA_LEVEL, FLAME }

## Lever behavior mode
enum LeverMode { 
	TOGGLE,  ## Standard on/off toggle - stays in state until interacted again
	TIMED    ## Activates then auto-deactivates after duration (for timed puzzles)
}

@export_group("Channel System")
## Channel to broadcast on when activated/deactivated
## Leave empty to use legacy NodePath system
## Set same channel on receiver objects (Gate, Flame, etc.) to connect them
@export var channel: StringName = &""

@export_group("Lever Settings")
@export var mode: LeverMode = LeverMode.TOGGLE
## How long lever stays active in TIMED mode (seconds)
@export var timer_duration: float = 3.0
@export var is_activated: bool = false
## Legacy target type - prefer using channel system for new designs
@export var target_type: LeverTarget = LeverTarget.SIGNAL_ONLY

@export_group("Water Control")
@export var water_node: NodePath  ## Path to water node to control
@export var water_on_level: float = -50.0  ## surface_pos_y when ON (negative = higher)
@export var water_off_level: float = 50.0  ## surface_pos_y when OFF (positive = lower)
@export var water_transition_time: float = 2.0

@export_group("Gate Control")
@export var gate_node: NodePath  ## Path to gate node to control

@export_group("Lava Control")
@export var lava_node: NodePath  ## Path to lava pool to control
@export var lava_drain_time: float = 2.0  ## How fast lava drains
@export var lava_fill_time: float = 3.0  ## How fast lava fills (slower = more tension)

@export_group("Flame Control")
@export var flame_node: NodePath  ## Path to flame hazard to control

signal lever_activated
signal lever_deactivated

var player_is_near: bool = false
var _water_ref: Node = null
var _gate_ref: Node = null
var _lava_ref: Node = null
var _flame_ref: Node = null
var _timer: Timer = null

func _ready() -> void:
	update_animation()
	
	# Create timer for timed mode
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	
	# Cache node references
	if not water_node.is_empty():
		_water_ref = get_node_or_null(water_node)
	if not gate_node.is_empty():
		_gate_ref = get_node_or_null(gate_node)
	if not lava_node.is_empty():
		_lava_ref = get_node_or_null(lava_node)
	if not flame_node.is_empty():
		_flame_ref = get_node_or_null(flame_node)

func _process(_delta: float) -> void:
	if player_is_near and Input.is_action_just_pressed("interact"):
		activate()

func activate() -> void:
	# In TIMED mode, ignore if already active (player must wait for reset)
	if mode == LeverMode.TIMED and is_activated:
		return
	
	is_activated = not is_activated
	update_animation()

	if is_activated:
		lever_activated.emit()
		# Broadcast on channel (new system)
		if not channel.is_empty():
			InteractionChannel.activate(channel, self)
		# Legacy direct control
		_on_lever_on()
		# Start timer in TIMED mode
		if mode == LeverMode.TIMED:
			_timer.wait_time = timer_duration
			_timer.start()
	else:
		lever_deactivated.emit()
		# Broadcast on channel (new system)
		if not channel.is_empty():
			InteractionChannel.deactivate(channel, self)
		# Legacy direct control
		_on_lever_off()

func _on_timer_timeout() -> void:
	# Auto-deactivate when timer expires (TIMED mode only)
	if is_activated:
		is_activated = false
		update_animation()
		lever_deactivated.emit()
		if not channel.is_empty():
			InteractionChannel.deactivate(channel, self)
		_on_lever_off()

func _on_lever_on() -> void:
	match target_type:
		LeverTarget.WATER_LEVEL:
			if _water_ref and _water_ref.has_method("raise_water"):
				_water_ref.raise_water(water_on_level, water_transition_time)
		LeverTarget.GATE:
			if _gate_ref and _gate_ref.has_method("open_gate"):
				_gate_ref.open_gate()
		LeverTarget.LAVA_LEVEL:
			if _lava_ref and _lava_ref.has_method("drain"):
				_lava_ref.drain(lava_drain_time)
		LeverTarget.FLAME:
			if _flame_ref and _flame_ref.has_method("extinguish"):
				_flame_ref.extinguish()

func _on_lever_off() -> void:
	match target_type:
		LeverTarget.WATER_LEVEL:
			if _water_ref and _water_ref.has_method("lower_water"):
				_water_ref.lower_water(water_off_level, water_transition_time)
		LeverTarget.GATE:
			if _gate_ref and _gate_ref.has_method("close_gate"):
				_gate_ref.close_gate()
		LeverTarget.LAVA_LEVEL:
			if _lava_ref and _lava_ref.has_method("fill"):
				_lava_ref.fill(lava_fill_time)
		LeverTarget.FLAME:
			if _flame_ref and _flame_ref.has_method("ignite"):
				await _flame_ref.ignite()

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
