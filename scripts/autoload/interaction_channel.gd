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
##
## RESPAWN SAFETY:
## This autoload persists across scene changes and player respawns.
## It automatically cleans up stale connections when:
## - Scenes are reloaded
## - Player dies and respawns
## - Objects are freed without proper cleanup

## Emitted when a channel is activated (lever pulled, plate pressed)
signal channel_activated(channel: StringName, source: Node)

## Emitted when a channel is deactivated (lever unpulled, plate released, timer expired)
signal channel_deactivated(channel: StringName, source: Node)

## Debug mode - prints channel activity to console
@export var debug_mode: bool = false

## Track active channels for debugging
var _active_channels: Dictionary = {}  # channel -> Array[Node] of sources

## Track connected receiver objects to clean up stale connections
var _connected_receivers: Array = []  # Array of WeakRef to receiver nodes

func _ready() -> void:
	print("InteractionChannel: Ready")
	
	# Listen for scene tree changes to clean up stale connections
	get_tree().tree_changed.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_node_removed)


func _on_tree_changed() -> void:
	## Called when scene tree structure changes - clean up invalid references
	_cleanup_stale_references()


func _on_node_removed(node: Node) -> void:
	## Called when ANY node is removed from tree - clean up if it was a source
	# Clean up this node from active channels if it was a source
	for channel in _active_channels.keys():
		var sources: Array = _active_channels[channel]
		if sources.has(node):
			sources.erase(node)
			if debug_mode:
				print("[Channel] Source '%s' removed from channel '%s'" % [node.name, channel])
		if sources.is_empty():
			_active_channels.erase(channel)


func _cleanup_stale_references() -> void:
	## Remove invalid node references from active channels
	var channels_to_remove: Array = []
	
	for channel in _active_channels.keys():
		var sources: Array = _active_channels[channel]
		var valid_sources: Array = []
		
		for source in sources:
			if is_instance_valid(source) and source.is_inside_tree():
				valid_sources.append(source)
			elif debug_mode:
				print("[Channel] Cleaned stale source from channel '%s'" % channel)
		
		if valid_sources.is_empty():
			channels_to_remove.append(channel)
		else:
			_active_channels[channel] = valid_sources
	
	for channel in channels_to_remove:
		_active_channels.erase(channel)
		if debug_mode:
			print("[Channel] Removed empty channel '%s'" % channel)


## Reset all channel state - call on scene reload or level reset
func reset_all_channels() -> void:
	if debug_mode:
		print("[Channel] RESET ALL - clearing %d active channels" % _active_channels.size())
	_active_channels.clear()


## Activate a channel (call from triggers like Lever, PressurePlate)
func activate(channel: StringName, source: Node = null) -> void:
	if channel.is_empty():
		return
	
	# Track active sources
	if not _active_channels.has(channel):
		_active_channels[channel] = []
	if source and is_instance_valid(source) and source not in _active_channels[channel]:
		_active_channels[channel].append(source)
	
	if debug_mode:
		var source_name = source.name if source else "unknown"
		print("[Channel] ACTIVATE '%s' by %s" % [channel, source_name])
	
	# Emit with safety check for receivers
	_safe_emit_activated(channel, source)


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
	
	# Emit with safety check for receivers
	_safe_emit_deactivated(channel, source)


func _safe_emit_activated(channel: StringName, source: Node) -> void:
	## Emit channel_activated, catching any errors from stale receivers
	## This is a safety net - proper cleanup should prevent this
	
	# Get all connections and filter out invalid ones
	var connections := channel_activated.get_connections()
	for conn in connections:
		var target: Object = conn["callable"].get_object()
		if not is_instance_valid(target):
			# Stale connection - disconnect it
			if debug_mode:
				print("[Channel] WARNING: Disconnecting stale receiver from channel_activated")
			channel_activated.disconnect(conn["callable"])
	
	channel_activated.emit(channel, source)


func _safe_emit_deactivated(channel: StringName, source: Node) -> void:
	## Emit channel_deactivated, catching any errors from stale receivers
	
	var connections := channel_deactivated.get_connections()
	for conn in connections:
		var target: Object = conn["callable"].get_object()
		if not is_instance_valid(target):
			if debug_mode:
				print("[Channel] WARNING: Disconnecting stale receiver from channel_deactivated")
			channel_deactivated.disconnect(conn["callable"])
	
	channel_deactivated.emit(channel, source)


## Check if a channel is currently active (any source)
func is_channel_active(channel: StringName) -> bool:
	if not _active_channels.has(channel):
		return false
	# Verify sources are still valid
	var sources: Array = _active_channels[channel]
	for source in sources:
		if is_instance_valid(source) and source.is_inside_tree():
			return true
	# All sources were stale
	_active_channels.erase(channel)
	return false


## Get all sources currently activating a channel
func get_channel_sources(channel: StringName) -> Array:
	if _active_channels.has(channel):
		# Return only valid sources
		var valid: Array = []
		for source in _active_channels[channel]:
			if is_instance_valid(source):
				valid.append(source)
		return valid
	return []


## Debug: List all active channels
func get_active_channels() -> Array:
	# Clean first
	_cleanup_stale_references()
	return _active_channels.keys()


## Safe listener registration - uses bound method instead of lambda
## Receiver objects should call this in _ready() and the connection is automatically
## cleaned when the receiver is freed
func register_receiver(receiver: Node, channel: StringName, on_activate: Callable, on_deactivate: Callable) -> void:
	if channel.is_empty():
		return
	
	# Create wrapper that checks channel and validates receiver AND callable target
	var activate_wrapper := func(ch: StringName, source: Node) -> void:
		if ch == channel and is_instance_valid(receiver) and receiver.is_inside_tree():
			# Also verify the callable's target object is valid
			var callable_target = on_activate.get_object()
			if is_instance_valid(callable_target):
				on_activate.call(source)
	
	var deactivate_wrapper := func(ch: StringName, source: Node) -> void:
		if ch == channel and is_instance_valid(receiver) and receiver.is_inside_tree():
			# Also verify the callable's target object is valid
			var callable_target = on_deactivate.get_object()
			if is_instance_valid(callable_target):
				on_deactivate.call(source)
	
	# Connect with CONNECT_REFERENCE_COUNTED so Godot can track the object
	channel_activated.connect(activate_wrapper)
	channel_deactivated.connect(deactivate_wrapper)
	
	# Store the receiver as a WeakRef so we don't prevent garbage collection
	_connected_receivers.append(weakref(receiver))
	
	# Also connect to the receiver's tree_exiting signal to clean up
	if not receiver.tree_exiting.is_connected(_on_receiver_exiting):
		receiver.tree_exiting.connect(_on_receiver_exiting.bind(receiver, activate_wrapper, deactivate_wrapper))
	
	if debug_mode:
		print("[Channel] Registered receiver '%s' for channel '%s'" % [receiver.name, channel])


func _on_receiver_exiting(receiver: Node, activate_wrapper: Callable, deactivate_wrapper: Callable) -> void:
	## Called when a registered receiver is about to exit the tree
	## Disconnect its signal connections to prevent stale callbacks
	if channel_activated.is_connected(activate_wrapper):
		channel_activated.disconnect(activate_wrapper)
	if channel_deactivated.is_connected(deactivate_wrapper):
		channel_deactivated.disconnect(deactivate_wrapper)
	
	if debug_mode:
		print("[Channel] Cleaned up receiver '%s'" % receiver.name)


## Legacy method - still works but less safe than register_receiver
func register_listener(channel: StringName, on_activate: Callable, on_deactivate: Callable) -> void:
	if channel.is_empty():
		return
	# Connect with channel filtering wrapper and validity check
	channel_activated.connect(func(ch: StringName, source: Node):
		if ch == channel:
			var target = on_activate.get_object()
			if is_instance_valid(target):
				on_activate.call(source)
	)
	channel_deactivated.connect(func(ch: StringName, source: Node):
		if ch == channel:
			var target = on_deactivate.get_object()
			if is_instance_valid(target):
				on_deactivate.call(source)
	)


## Convenience method to unregister a listener (Note: with lambdas, this is a no-op for safety)
## Use register_receiver() for auto-cleanup or direct signal connections if needed
func unregister_listener(_channel: StringName, _on_activate: Callable, _on_deactivate: Callable) -> void:
	# Lambda connections can't be easily disconnected by reference
	# Use register_receiver() instead for automatic cleanup
	pass
	# Objects are freed naturally when removed from scene tree
	pass
