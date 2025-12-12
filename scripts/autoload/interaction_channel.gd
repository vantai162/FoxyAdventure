extends Node
class_name InteractionChannelManager
## Singleton that manages channel-based interactions between objects
## 
## Designers use channels to connect triggers (levers, pressure plates) to 
## receivers (gates, flames, spikes) without writing code.
##
## Usage:
## - Set `channel` on trigger objects (Lever, PressurePlate, TimerLever)
## - Set `listen_channel` on receiver objects (Gate, Flame, SpikeRetractable)
## - Same channel name = connected
##
## Supports:
## - One trigger → many receivers (all gates with same channel open)
## - Many triggers → one receiver (any lever with same channel opens gate)
## - Activate/Deactivate pairs (lever on/off, pressure plate press/release)

## Emitted when a channel is activated (lever pulled, plate pressed)
signal channel_activated(channel: StringName, source: Node)

## Emitted when a channel is deactivated (lever unpulled, plate released, timer expired)
signal channel_deactivated(channel: StringName, source: Node)

## Debug mode - prints channel activity to console
@export var debug_mode: bool = false

## Track active channels for debugging
var _active_channels: Dictionary = {}  # channel -> Array[Node] of sources

func _ready() -> void:
	print("InteractionChannel: Ready")

## Activate a channel (call from triggers like Lever, PressurePlate)
func activate(channel: StringName, source: Node = null) -> void:
	if channel.is_empty():
		return
	
	# Track active sources
	if not _active_channels.has(channel):
		_active_channels[channel] = []
	if source and source not in _active_channels[channel]:
		_active_channels[channel].append(source)
	
	if debug_mode:
		var source_name = source.name if source else "unknown"
		print("[Channel] ACTIVATE '%s' by %s" % [channel, source_name])
	
	channel_activated.emit(channel, source)

## Deactivate a channel (call from triggers when turned off)
func deactivate(channel: StringName, source: Node = null) -> void:
	if channel.is_empty():
		return
	
	# Remove from active sources
	if _active_channels.has(channel) and source:
		_active_channels[channel].erase(source)
		if _active_channels[channel].is_empty():
			_active_channels.erase(channel)
	
	if debug_mode:
		var source_name = source.name if source else "unknown"
		print("[Channel] DEACTIVATE '%s' by %s" % [channel, source_name])
	
	channel_deactivated.emit(channel, source)

## Check if a channel is currently active (any source)
func is_channel_active(channel: StringName) -> bool:
	return _active_channels.has(channel) and not _active_channels[channel].is_empty()


## Get all sources currently activating a channel
func get_channel_sources(channel: StringName) -> Array:
	if _active_channels.has(channel):
		return _active_channels[channel].duplicate()
	return []

## Debug: List all active channels
func get_active_channels() -> Array:
	return _active_channels.keys()

## Convenience method to register a listener for a specific channel
## Connects to both activated and deactivated signals with channel filtering
func register_listener(channel: StringName, on_activate: Callable, on_deactivate: Callable) -> void:
	if channel.is_empty():
		return
	# Connect with channel filtering wrapper
	channel_activated.connect(func(ch: StringName, source: Node):
		if ch == channel:
			on_activate.call(source)
	)
	channel_deactivated.connect(func(ch: StringName, source: Node):
		if ch == channel:
			on_deactivate.call(source)
	)

## Convenience method to unregister a listener (Note: with lambdas, this is a no-op for safety)
## Objects should be freed naturally or use direct signal connections if unregistration is needed
func unregister_listener(_channel: StringName, _on_activate: Callable, _on_deactivate: Callable) -> void:
	# Lambda connections can't be easily disconnected by reference
	# Objects are freed naturally when removed from scene tree
	pass
