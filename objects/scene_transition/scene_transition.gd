@tool
extends Area2D
class_name SceneTransition
## Seamless cross-scene transition with directional wipe effect
## Player walks through edge to transition to another scene file
## 
## SETUP:
## 1. Place at edge of level where player exits
## 2. Set target_scene to the next level's path
## 3. Set target_spawn_name to matching transition's name in target scene
## 4. The wipe direction is automatic based on player movement

signal transition_started
signal transition_completed

enum Direction { LEFT, RIGHT, UP, DOWN }

@export_group("Target Scene")
## Path to the target scene file
@export_file("*.tscn") var target_scene: String = ""
## Name of the SceneTransition in target scene to spawn at
@export var target_spawn_name: String = ""

@export_group("Transition Behavior")
## Direction player is moving when transitioning (auto-detected if AUTO)
@export var exit_direction: Direction = Direction.RIGHT
## Spawn offset from the target transition position
@export var spawn_offset: Vector2 = Vector2(48, 0)
## Minimum velocity to trigger transition
@export var trigger_threshold: float = 10.0

@export_group("Wipe Effect")
## Duration of the wipe transition - FAST for whoosh feel (0.15-0.2 recommended)
@export var wipe_duration: float = 0.18
## Color of the wipe
@export var wipe_color: Color = Color.BLACK

@export_group("Preloading")
## Distance from transition to start preloading (0 = don't preload until triggered)
## Recommendation: Set to ~300-500px so it loads as player approaches, not on level start
@export var preload_distance: float = 400.0
## Whether preloading has started
var _preload_started: bool = false

@export_group("Editor Preview")
## Show direction indicator in editor
@export var show_indicator: bool = true:
	set(value):
		show_indicator = value
		queue_redraw()
@export var indicator_color: Color = Color(0.9, 0.5, 0.2, 0.9)

var is_transitioning: bool = false
var player_in_zone: bool = false
var _preloaded_scene: PackedScene = null
var _player_ref: Node2D = null  # Cache player reference

@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Setup collision
	collision_layer = 0
	collision_mask = 2  # Player layer
	
	_setup_collision_shape()
	
	# DON'T preload immediately - we'll do it when player gets close
	# This keeps initial level load fast
	set_process(true)  # Enable _process for proximity checking

func _setup_collision_shape() -> void:
	if collision_shape == null:
		return
	
	var shape = collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape
	
	# Auto-size based on direction
	match exit_direction:
		Direction.LEFT, Direction.RIGHT:
			shape.size = Vector2(24, 160)
		Direction.UP, Direction.DOWN:
			shape.size = Vector2(160, 24)


func _start_preload() -> void:
	if target_scene.is_empty() or _preload_started:
		return
	_preload_started = true
	# Low priority background load - doesn't hitch gameplay
	ResourceLoader.load_threaded_request(target_scene, "", false, ResourceLoader.CACHE_MODE_REUSE)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	
	# Get/cache player reference
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = _get_player()
	
	if _player_ref == null:
		return
	
	# PROXIMITY-BASED PRELOADING
	# Only start loading when player gets close - keeps initial level load fast
	if not _preload_started and preload_distance > 0 and not target_scene.is_empty():
		var distance_to_player = global_position.distance_to(_player_ref.global_position)
		if distance_to_player <= preload_distance:
			_start_preload()
	
	# Check if preload completed
	if _preload_started and _preloaded_scene == null:
		var status = ResourceLoader.load_threaded_get_status(target_scene)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_preloaded_scene = ResourceLoader.load_threaded_get(target_scene)
			# Scene ready - no need to keep checking
			# (but keep process for editor redraw)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not player_in_zone or is_transitioning:
		return
	
	var player = _get_player()
	if player == null:
		return
	
	if _is_player_moving_through(player):
		_trigger_transition(player)


func _get_player() -> Node2D:
	if _player_ref and is_instance_valid(_player_ref):
		return _player_ref
	if GameManager and GameManager.player:
		_player_ref = GameManager.player
		return _player_ref
	var found = get_tree().get_first_node_in_group("player")
	if found:
		_player_ref = found
	return _player_ref

func _is_player_moving_through(player: Node2D) -> bool:
	if not player or not "velocity" in player:
		return false
	
	var vel = player.velocity
	
	match exit_direction:
		Direction.RIGHT:
			return vel.x > trigger_threshold
		Direction.LEFT:
			return vel.x < -trigger_threshold
		Direction.DOWN:
			return vel.y > trigger_threshold
		Direction.UP:
			return vel.y < -trigger_threshold
	
	return false

func _trigger_transition(player: Node2D) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	transition_started.emit()
	
	# DON'T freeze the player! Keep them walking into the wipe.
	# This creates the "whoosh" feeling - player momentum continues
	# The wipe catches up with them mid-stride.
	
	# Store player's exit velocity for the target scene to use
	var exit_velocity = player.velocity if player and "velocity" in player else Vector2.ZERO
	
	# Store player state
	if GameManager and player and player.has_method("save_state"):
		GameManager.save_player_state(player)
	
	# Store spawn info for target scene
	GameManager.target_portal_name = target_spawn_name
	
	# Store transition direction for wipe-in effect
	_store_transition_direction()
	
	# Perform directional wipe OUT using global TransitionEffects
	var wipe_dir = _direction_to_wipe_direction(exit_direction)
	if get_node_or_null("/root/TransitionEffects"):
		await TransitionEffects.wipe_out(wipe_dir, wipe_duration * 0.5, wipe_color)
	else:
		# Fallback: use GameManager fade
		await _wipe_out()
	
	# Change scene
	_change_to_target_scene()

func _store_transition_direction() -> void:
	# Store in GameManager for target scene to read
	if GameManager:
		# Use meta to store arbitrary data
		GameManager.set_meta("incoming_transition_direction", exit_direction)
		GameManager.set_meta("incoming_transition_spawn", target_spawn_name)

func _direction_to_wipe_direction(dir: Direction) -> int:
	# Maps to TransitionEffects.WipeDirection enum
	match dir:
		Direction.RIGHT: return 1  # WipeDirection.RIGHT
		Direction.LEFT: return 0   # WipeDirection.LEFT
		Direction.DOWN: return 3   # WipeDirection.DOWN
		Direction.UP: return 2     # WipeDirection.UP
	return 1

func _wipe_out() -> void:
	# Create wipe overlay
	var wipe = _create_wipe_overlay()
	
	# Animate wipe based on direction
	var tween = create_tween()
	var start_pos: Vector2
	var end_pos: Vector2
	var viewport_size = get_viewport().get_visible_rect().size
	
	match exit_direction:
		Direction.RIGHT:
			# Wipe from right to left
			start_pos = Vector2(viewport_size.x, 0)
			end_pos = Vector2(0, 0)
		Direction.LEFT:
			# Wipe from left to right
			start_pos = Vector2(-viewport_size.x, 0)
			end_pos = Vector2(0, 0)
		Direction.DOWN:
			# Wipe from bottom to top
			start_pos = Vector2(0, viewport_size.y)
			end_pos = Vector2(0, 0)
		Direction.UP:
			# Wipe from top to bottom
			start_pos = Vector2(0, -viewport_size.y)
			end_pos = Vector2(0, 0)
	
	wipe.position = start_pos
	tween.tween_property(wipe, "position", end_pos, wipe_duration * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	await tween.finished

func _create_wipe_overlay() -> ColorRect:
	# Create canvas layer for wipe
	var canvas = CanvasLayer.new()
	canvas.name = "WipeLayer"
	canvas.layer = 100  # On top of everything
	get_tree().root.add_child(canvas)
	
	# Create oversized color rect
	var wipe = ColorRect.new()
	wipe.name = "WipeRect"
	var viewport_size = get_viewport().get_visible_rect().size
	wipe.size = viewport_size * 2  # Oversized to cover during movement
	wipe.position = Vector2.ZERO
	wipe.color = wipe_color
	canvas.add_child(wipe)
	
	return wipe

func _change_to_target_scene() -> void:
	if _preloaded_scene != null:
		# Use preloaded scene for instant switch
		get_tree().change_scene_to_packed(_preloaded_scene)
	elif not target_scene.is_empty():
		# Fallback to file load
		get_tree().change_scene_to_file(target_scene)
	else:
		printerr("SceneTransition: No target scene set!")
		is_transitioning = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_zone = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_zone = false

## Get the spawn position for incoming players
func get_spawn_position() -> Vector2:
	return global_position + spawn_offset

## Get opposite direction
static func get_opposite_direction(dir: Direction) -> Direction:
	match dir:
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
		Direction.UP: return Direction.DOWN
		Direction.DOWN: return Direction.UP
	return Direction.RIGHT

## Editor drawing
func _draw() -> void:
	if not Engine.is_editor_hint() or not show_indicator:
		return
	
	# Draw direction arrow
	var arrow_size = 24.0
	var arrow_dir: Vector2
	
	match exit_direction:
		Direction.RIGHT:
			arrow_dir = Vector2.RIGHT
		Direction.LEFT:
			arrow_dir = Vector2.LEFT
		Direction.UP:
			arrow_dir = Vector2.UP
		Direction.DOWN:
			arrow_dir = Vector2.DOWN
	
	var arrow_end = arrow_dir * arrow_size
	var arrow_perp = arrow_dir.rotated(PI / 2)
	
	# Main arrow line
	draw_line(Vector2.ZERO, arrow_end, indicator_color, 3.0)
	
	# Arrow head
	draw_line(arrow_end, arrow_end - arrow_dir * 10 + arrow_perp * 6, indicator_color, 3.0)
	draw_line(arrow_end, arrow_end - arrow_dir * 10 - arrow_perp * 6, indicator_color, 3.0)
	
	# Label
	var font := ThemeDB.fallback_font
	var label := "→ " + target_scene.get_file() if not target_scene.is_empty() else "→ [NO TARGET]"
	draw_string(font, Vector2(-40, -20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, indicator_color)
