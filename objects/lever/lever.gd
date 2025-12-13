# Lever - Interactive switch for gates, water, lava, flames, and custom actions
# Uses Channel System: set a channel name, receivers listen on the same channel
# Supports both toggle mode (stays on/off) and timed mode (auto-resets after duration)
@tool
extends Area2D
class_name Lever

## Lever behavior mode
enum LeverMode { 
	TOGGLE,  ## Standard on/off toggle - stays in state until interacted again
	TIMED    ## Activates then auto-deactivates after duration (for timed puzzles)
}

@export_group("Channel System")
## Channel to broadcast on when activated/deactivated
## Set same channel on receiver objects (Gate, Flame, etc.) to connect them
@export var channel: StringName = &""

@export_group("Lever Settings")
@export var mode: LeverMode = LeverMode.TOGGLE
## How long lever stays active in TIMED mode (seconds)
@export var timer_duration: float = 3.0
@export var is_activated: bool = false:
	set(value):
		is_activated = value
		update_animation()

@export_group("Feedback")
@export var activation_sound: String = "lever_click"  ## Sound to play on activation
@export var scale_punch: float = 1.3  ## Scale punch on activation (1.0 = no punch)
@export var punch_duration: float = 0.15  ## Duration of scale punch

signal lever_activated
signal lever_deactivated

var player_is_near: bool = false
var _timer: Timer = null

func _ready() -> void:
	update_animation()
	
	# Skip gameplay logic in editor
	if Engine.is_editor_hint():
		return
	
	# Create timer for timed mode
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

func _process(_delta: float) -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return
	
	if player_is_near and Input.is_action_just_pressed("interact"):
		activate()

func activate() -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return
	
	# In TIMED mode, ignore if already active (player must wait for reset)
	if mode == LeverMode.TIMED and is_activated:
		return
	
	is_activated = not is_activated
	update_animation()
	_play_activation_feedback()

	if is_activated:
		lever_activated.emit()
		# Broadcast on channel
		if not channel.is_empty():
			var channel_manager = get_node_or_null("/root/InteractionChannel")
			if channel_manager:
				channel_manager.activate(channel, self)
		# Start timer in TIMED mode
		if mode == LeverMode.TIMED:
			_timer.wait_time = timer_duration
			_timer.start()
	else:
		lever_deactivated.emit()
		# Broadcast on channel
		if not channel.is_empty():
			var channel_manager = get_node_or_null("/root/InteractionChannel")
			if channel_manager:
				channel_manager.deactivate(channel, self)

func _play_activation_feedback() -> void:
	## Visual and audio feedback when lever is toggled
	# Sound
	if not activation_sound.is_empty():
		AudioManager.play_sound(activation_sound, 15.0)
	
	# Scale punch (satisfying "thunk" feel)
	if scale_punch != 1.0 and has_node("AnimatedSprite2D"):
		var sprite = $AnimatedSprite2D
		var original_scale = sprite.scale
		var tween = create_tween()
		tween.tween_property(sprite, "scale", original_scale * scale_punch, punch_duration * 0.3)
		tween.tween_property(sprite, "scale", original_scale, punch_duration * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _on_timer_timeout() -> void:
	# Auto-deactivate when timer expires (TIMED mode only)
	if is_activated:
		is_activated = false
		update_animation()
		lever_deactivated.emit()
		if not channel.is_empty():
			var channel_manager = get_node_or_null("/root/InteractionChannel")
			if channel_manager:
				channel_manager.deactivate(channel, self)

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
