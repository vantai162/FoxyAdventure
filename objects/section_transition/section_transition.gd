extends Area2D
class_name SectionTransition

## Seamless transition trigger for moving between level sections
## Place at edges of sections - player walks through to transition
## Designer-friendly: set direction, target, and it just works

signal transition_started
signal transition_completed

enum Direction { LEFT, RIGHT, UP, DOWN }

@export_group("Transition Setup")
@export var direction: Direction = Direction.RIGHT  ## Which edge this transition is on
@export var target_transition_name: String = ""  ## Name of matching transition in target (optional)
@export var target_section: NodePath  ## Optional: path to target LevelSection

@export_group("Timing")
@export var transition_duration: float = 0.3  ## Fade duration
@export var auto_trigger: bool = true  ## Trigger when player moves through
@export var trigger_threshold: float = 10.0  ## Minimum velocity to trigger

@export_group("Player Spawn")
@export var spawn_offset: Vector2 = Vector2(48, 0)  ## Offset from matching transition

@export_group("Camera")
@export var update_camera_bounds: bool = true  ## Update camera to new section bounds

@export_group("Debug")
@export var show_debug: bool = false  ## Show trigger zone in editor

var is_transitioning: bool = false
var player_in_zone: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Ensure collision layer setup
	collision_layer = 0
	collision_mask = 2  # Player layer
	
	_setup_collision_shape()
	
	if show_debug and has_node("DebugSprite"):
		$DebugSprite.visible = true

func _setup_collision_shape() -> void:
	if collision_shape == null or collision_shape.shape == null:
		return
	
	var shape = collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape
	
	# Auto-size based on direction
	match direction:
		Direction.LEFT, Direction.RIGHT:
			shape.size = Vector2(16, 128)
		Direction.UP, Direction.DOWN:
			shape.size = Vector2(128, 16)

func _physics_process(_delta: float) -> void:
	if not auto_trigger or not player_in_zone or is_transitioning:
		return
	
	var player = _get_player()
	if player == null:
		return
	
	if _is_player_moving_through(player):
		_trigger_transition()

func _get_player() -> Node2D:
	if GameManager and GameManager.player:
		return GameManager.player
	return get_tree().get_first_node_in_group("player")

func _is_player_moving_through(player: Node2D) -> bool:
	if not player or not "velocity" in player:
		return false
	
	var vel = player.velocity
	
	match direction:
		Direction.RIGHT:
			return vel.x > trigger_threshold
		Direction.LEFT:
			return vel.x < -trigger_threshold
		Direction.DOWN:
			return vel.y > trigger_threshold
		Direction.UP:
			return vel.y < -trigger_threshold
	
	return false

func _trigger_transition() -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	transition_started.emit()
	
	var player = _get_player()
	if player == null:
		is_transitioning = false
		return
	
	# Pause during transition
	if GameManager:
		GameManager.paused = true
	
	# Fade out
	if GameManager and GameManager.has_method("fade_to_black"):
		await GameManager.fade_to_black(transition_duration)
	else:
		await get_tree().create_timer(transition_duration).timeout
	
	# Move player
	var new_position = _calculate_spawn_position()
	player.global_position = new_position
	player.velocity = Vector2.ZERO
	
	# Update camera
	if update_camera_bounds:
		_update_camera_to_section(player)
	
	# Fade in
	if GameManager and GameManager.has_method("fade_from_black"):
		await GameManager.fade_from_black(transition_duration)
	else:
		await get_tree().create_timer(transition_duration).timeout
	
	# Resume
	if GameManager:
		GameManager.paused = false
	
	is_transitioning = false
	transition_completed.emit()

func _calculate_spawn_position() -> Vector2:
	# Try to find matching transition
	var target = _find_target_transition()
	if target != null:
		return target.global_position + _get_exit_offset(target.direction)
	
	# Fallback: offset from this transition
	return global_position + spawn_offset

func _get_exit_offset(exit_direction: Direction) -> Vector2:
	match exit_direction:
		Direction.LEFT:
			return Vector2(-48, 0)
		Direction.RIGHT:
			return Vector2(48, 0)
		Direction.UP:
			return Vector2(0, -48)
		Direction.DOWN:
			return Vector2(0, 48)
	return Vector2.ZERO

func _find_target_transition() -> SectionTransition:
	if target_transition_name.is_empty():
		return null
	
	var root = get_tree().current_scene
	var transitions = root.find_children("*", "SectionTransition", true, false)
	
	for t in transitions:
		if t.name == target_transition_name and t != self:
			return t as SectionTransition
	
	return null

func _update_camera_to_section(player: Node2D) -> void:
	var camera = player.get_node_or_null("Camera2D")
	if camera == null:
		return
	
	# Try to get bounds from target section
	if target_section != NodePath(""):
		var section = get_node_or_null(target_section)
		if section != null and section.has_method("get_camera_bounds"):
			var bounds: Rect2 = section.get_camera_bounds()
			camera.limit_left = int(bounds.position.x)
			camera.limit_top = int(bounds.position.y)
			camera.limit_right = int(bounds.position.x + bounds.size.x)
			camera.limit_bottom = int(bounds.position.y + bounds.size.y)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_zone = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_zone = false

## Manually trigger the transition (for scripted events)
func force_transition() -> void:
	_trigger_transition()

## Get opposite direction helper
static func get_opposite_direction(dir: Direction) -> Direction:
	match dir:
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
		Direction.UP: return Direction.DOWN
		Direction.DOWN: return Direction.UP
	return Direction.RIGHT
