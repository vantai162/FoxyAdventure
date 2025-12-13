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

## Settings UI for pause menu
@onready var settings_ui = preload("res://scenes/game_screen/settings_popup.tscn")


## CRITICAL: Must set current_stage BEFORE _ready() so checkpoints work
func _enter_tree() -> void:
	GameManager.current_stage = self


func _ready() -> void:
	# Handle editor-placed player vs GameManager player
	_handle_editor_player()
	
	# Spawn player if needed
	if GameManager.player == null:
		GameManager.request_player_spawn()
	
	# Handle portal teleportation or scene transition spawn
	_handle_portal_spawn()
	_handle_scene_transition_spawn()
	
	# Set camera bounds for this stage
	_setup_camera_bounds()
	
	# Stage-specific initialization
	_on_stage_ready()
	
	# Perform appropriate transition-in effect
	await _perform_transition_in()


func _process(delta: float) -> void:
	# Pause menu handling
	if Input.is_action_just_pressed("pause"):
		if GameManager.paused:
			return
		_open_pause_menu()
	
	# Stage-specific update
	_on_stage_process(delta)


func _handle_editor_player() -> void:
	## Handle player placed in editor - remove if GameManager has one
	var editor_player = find_child("Foxy", true, false)
	if editor_player != null:
		if GameManager.player == null and GameManager.persistent_player_data.is_empty():
			# No existing player data - use the editor-placed one
			GameManager.player = editor_player
		else:
			# GameManager has player data - remove editor one
			editor_player.queue_free()


func _handle_portal_spawn() -> void:
	## Teleport player to target portal if specified
	if not GameManager.target_portal_name.is_empty():
		var portal = find_child(GameManager.target_portal_name)
		if portal != null and GameManager.player != null:
			GameManager.player.global_position = portal.global_position
		GameManager.target_portal_name = ""


func _handle_scene_transition_spawn() -> void:
	## Handle spawning at SceneTransition after cross-scene transition
	if not GameManager.has_meta("incoming_transition_spawn"):
		return
	
	var spawn_name: String = GameManager.get_meta("incoming_transition_spawn", "")
	if spawn_name.is_empty():
		return
	
	# Find the matching SceneTransition
	var transitions = find_children("*", "SceneTransition", true, false)
	for t in transitions:
		if t.name == spawn_name:
			if GameManager.player != null:
				GameManager.player.global_position = t.get_spawn_position()
			break
	
	# Clear the meta (consumed)
	GameManager.remove_meta("incoming_transition_spawn")


func _perform_transition_in() -> void:
	## Perform the appropriate transition-in effect
	## Checks if we came from a SceneTransition (directional wipe) or regular (fade)
	
	if GameManager.has_meta("incoming_transition_direction"):
		# We came from a SceneTransition - do directional wipe-in
		var incoming_dir: int = GameManager.get_meta("incoming_transition_direction", 1)
		GameManager.remove_meta("incoming_transition_direction")
		
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
		
		if get_node_or_null("/root/TransitionEffects"):
			await TransitionEffects.wipe_in(wipe_dir, 0.18)  # Match whoosh timing
		else:
			# Fallback to regular fade
			await GameManager.fade_from_black()
	else:
		# Regular fade in
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
