class_name StageBase
extends Node2D
## Base class for all stage scenes. Handles GameManager integration, camera bounds, 
## player spawning, and common stage logic.

## Camera boundary settings - override in child scripts or set in inspector
@export_group("Camera Bounds")
@export var camera_left: float = 0.0
@export var camera_right: float = 1280.0
@export var camera_top: float = 0.0
@export var camera_bottom: float = 720.0

@export_group("Debug")
## Enable verbose debug logging for transition/camera issues
@export var debug_logging: bool = false

## Settings UI for pause menu
@onready var settings_ui = preload("res://scenes/game_screen/settings_popup.tscn")
var can_pause = true


## CRITICAL: Must set current_stage BEFORE _ready() so checkpoints work
## Also handle editor-placed player here to prevent double _ready() calls
func _enter_tree() -> void:
	GameManager.current_stage = self
	
	# Handle editor player EARLY - before its _ready() runs!
	# This prevents the torch from calling _ready() on a player that will be freed
	_handle_editor_player_early()


func _handle_editor_player_early() -> void:
	## Check for editor-placed player and remove it if GameManager has player data.
	## Must run in _enter_tree() to catch it before the player's _ready() cascades.
	var editor_player = find_child("Foxy", true, false)
	if editor_player == null:
		return
	
	# If GameManager already has player data (from scene transition), 
	# remove the editor player IMMEDIATELY (not deferred) to prevent its _ready()
	if not GameManager.persistent_player_data.is_empty():
		# Remove from tree immediately - prevents _ready() from running on children
		editor_player.get_parent().remove_child(editor_player)
		editor_player.queue_free()  # Clean up the orphaned node
	elif GameManager.player != null:
		# GameManager already has a live player - remove editor one
		editor_player.get_parent().remove_child(editor_player)
		editor_player.queue_free()
	else:
		# No existing player data - this IS the player (standalone testing)
		GameManager.player = editor_player


func _ready() -> void:
	# Editor player is already handled in _enter_tree()
	
	# Spawn player if needed (only if no editor player was kept)
	if GameManager.player == null:
		GameManager.request_player_spawn()
	
	# Handle portal teleportation or scene transition spawn
	_handle_portal_spawn()
	_handle_scene_transition_spawn()
	
	# Set camera bounds for this stage (MUST await to complete before transition)
	await _setup_camera_bounds()
	
	# Snap camera to player position BEFORE revealing (prevents jarring jump)
	_snap_camera_to_player()
	
	# Stage-specific initialization
	_on_stage_ready()
	
	# Perform appropriate transition-in effect
	await _perform_transition_in()


func _process(delta: float) -> void:
	# Pause menu handling
	if Input.is_action_just_pressed("pause") and can_pause:
		if GameManager.paused:
			return
		_open_pause_menu()
	
	# Stage-specific update
	_on_stage_process(delta)


func _handle_portal_spawn() -> void:
	## Teleport player to target portal if specified
	## NOTE: This is for LEGACY portal system (GameManager.change_stage).
	## Scene transitions use "incoming_transition_spawn" meta instead.
	## We skip this if a scene transition spawn is pending (it takes priority).
	
	if GameManager.has_meta("incoming_transition_spawn"):
		# Scene transition spawn will handle positioning, skip portal spawn
		GameManager.target_portal_name = ""
		return
	
	if GameManager.target_portal_name.is_empty():
		return
	
	var portal = find_child(GameManager.target_portal_name, true, false)
	if portal != null and GameManager.player != null:
		# For legacy portals, use raw position (they don't have spawn_offset)
		GameManager.player.global_position = portal.global_position
		if debug_logging:
			print("[StageBase] Legacy portal spawn at ", portal.global_position)
	
	GameManager.target_portal_name = ""


func _handle_scene_transition_spawn() -> void:
	## Handle spawning at SceneTransition after cross-scene transition
	## This is the AUTHORITATIVE spawn position for scene transitions.
	## It uses spawn_offset to place the player INSIDE the level bounds.
	
	if not GameManager.has_meta("incoming_transition_spawn"):
		return
	
	var spawn_name: String = GameManager.get_meta("incoming_transition_spawn", "")
	
	if spawn_name.is_empty():
		GameManager.remove_meta("incoming_transition_spawn")
		return
	
	# Find the spawn point by NAME (more reliable than type matching in Godot 4)
	# The transition might be nested under ExitZone or similar containers
	var spawn_point = find_child(spawn_name, true, false)
	
	if spawn_point == null:
		push_warning("StageBase: Could not find spawn point '%s'" % spawn_name)
		GameManager.remove_meta("incoming_transition_spawn")
		return
	
	if GameManager.player == null:
		push_warning("StageBase: No player to spawn!")
		GameManager.remove_meta("incoming_transition_spawn")
		return
	
	# Get spawn position - use get_spawn_position() if available (applies offset)
	# Otherwise fall back to global_position (no offset, not ideal)
	var spawn_pos: Vector2
	if spawn_point.has_method("get_spawn_position"):
		spawn_pos = spawn_point.get_spawn_position()
	else:
		push_warning("StageBase: Spawn point '%s' has no get_spawn_position(), using raw position" % spawn_name)
		spawn_pos = spawn_point.global_position
	
	GameManager.player.global_position = spawn_pos
	
	if debug_logging:
		print("[StageBase] Spawned player at ", spawn_pos, " (from transition '", spawn_name, "')")
	
	# Clear the meta (consumed)
	GameManager.remove_meta("incoming_transition_spawn")


func _perform_transition_in() -> void:
	## Perform the appropriate transition-in effect
	## Checks if we came from a SceneTransition (directional wipe) or regular (fade)
	
	# CRITICAL: Warm-up frames before ANY visual transition.
	# This ensures:
	# 1. All shaders are compiled (first-use compilation causes hitches)
	# 2. All textures are GPU-resident (upload latency)
	# 3. Physics world is stable (collision shapes registered)
	# 4. Camera is settled (no smoothing jumps)
	#
	# We wait for 2-3 process frames, not just timer time, because
	# we need the ENGINE to run its full update loop including rendering.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	if GameManager.has_meta("incoming_transition_direction"):
		# We came from a SceneTransition - do directional wipe-in
		var incoming_dir: int = GameManager.get_meta("incoming_transition_direction", 1)
		GameManager.remove_meta("incoming_transition_direction")
		
		# Retrieve the wipe duration used on the source side for symmetry
		# Default to WIPE_DURATION_FAST (0.25s) if not stored
		var wipe_duration: float = GameManager.get_meta("incoming_transition_duration", 0.25)
		GameManager.remove_meta("incoming_transition_duration")
		
		# Wipe direction should be opposite of incoming direction
		# (if player walked RIGHT into transition, wipe should exit LEFT)
		var wipe_dir: int
		match incoming_dir:
			0: wipe_dir = 1  # LEFT -> exit RIGHT
			1: wipe_dir = 0  # RIGHT -> exit LEFT
			2: wipe_dir = 3  # UP -> exit DOWN
			3: wipe_dir = 2  # DOWN -> exit UP
			_: wipe_dir = 0
		
		# Unpause before wipe-in
		GameManager.paused = false
		
		var transition_fx = get_node_or_null("/root/TransitionEffects")
		if transition_fx:
			# Use symmetric duration for seamless flow
			await transition_fx.wipe_in(wipe_dir, wipe_duration)
		else:
			# Fallback to regular fade
			await GameManager.fade_from_black()
	else:
		# Regular fade in
		GameManager.paused = false
		await GameManager.fade_from_black()


func _setup_camera_bounds() -> void:
	## Set camera limits based on stage configuration
	# Wait a frame for player to be fully ready
	await get_tree().process_frame
	
	var player = GameManager.player
	if player == null:
		push_warning("StageBase: No player found for camera bounds setup")
		return
	
	var camera = player.get_node_or_null("Camera2D")
	if camera == null:
		push_warning("StageBase: No Camera2D found on player")
		return
	
	camera.set_level_bounds(camera_left, camera_right, camera_top, camera_bottom)
	if debug_logging:
		print("[StageBase] Camera bounds set: L=", camera_left, " R=", camera_right, " T=", camera_top, " B=", camera_bottom)


func _snap_camera_to_player() -> void:
	## Force camera to snap to player position immediately (no smoothing lag)
	## Call this BEFORE revealing the scene to prevent jarring camera jump
	var player = GameManager.player
	if player == null:
		if debug_logging:
			print("[StageBase] _snap_camera_to_player: No player!")
		return
	
	var camera = player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		if debug_logging:
			print("[StageBase] _snap_camera_to_player: No camera!")
		return
	
	if debug_logging:
		print("[StageBase] BEFORE snap - Player pos: ", player.global_position, " Camera global: ", camera.global_position)
	
	# Force immediate position update by resetting the camera
	# This ensures the camera is exactly where it should be before the wipe reveals
	camera.reset_smoothing()
	
	# Also force the camera to update its transform this frame
	camera.force_update_scroll()
	
	if debug_logging:
		print("[StageBase] AFTER snap - Camera global: ", camera.global_position, " Screen center: ", camera.get_screen_center_position())


func _open_pause_menu() -> void:
	## Open pause/settings menu
	var canvas_layer = get_node_or_null("CanvasLayer")
	if canvas_layer == null:
		# Create CanvasLayer if missing (for standalone sub-level testing)
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		canvas_layer.layer = 100
		add_child(canvas_layer)
	
	if settings_ui:
		var settings = settings_ui.instantiate()
		canvas_layer.add_child(settings)


## Override in child classes for stage-specific initialization
func _on_stage_ready() -> void:
	pass


## Override in child classes for stage-specific per-frame logic
func _on_stage_process(_delta: float) -> void:
	pass
