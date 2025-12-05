extends Area2D
class_name SectionTransition

## Triggers a transition when player walks through the edge
## Connects sections within the same level (like Hollow Knight / Celeste rooms)

signal transition_started
signal transition_completed

enum Direction { LEFT, RIGHT, UP, DOWN }

@export_group("Transition Settings")
@export var direction: Direction = Direction.RIGHT  ## Which edge this transition is on
@export var target_section: NodePath  ## Path to the target Section node
@export var target_transition_name: String = ""  ## Name of the matching transition in target section
@export var transition_duration: float = 0.3  ## Fade duration

@export_group("Player Spawn")
@export var spawn_offset: Vector2 = Vector2(32, 0)  ## Offset from this transition to spawn player

@export_group("Camera")
@export var update_camera_bounds: bool = true  ## Update camera limits to new section

var is_transitioning: bool = false
var player_in_zone: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Auto-configure collision shape based on direction
	_setup_collision_shape()

func _setup_collision_shape() -> void:
	# Ensure collision is a thin strip at the edge
	if collision_shape == null:
		return
	
	var shape = collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape
	
	# Make it a thin trigger zone
	match direction:
		Direction.LEFT, Direction.RIGHT:
			shape.size = Vector2(16, 128)  # Tall thin strip
		Direction.UP, Direction.DOWN:
			shape.size = Vector2(128, 16)  # Wide thin strip

func _physics_process(_delta: float) -> void:
	if not player_in_zone or is_transitioning:
		return
	
	var player = GameManager.player
	if player == null:
		return
	
	# Check if player is moving in the transition direction
	if _is_player_moving_through():
		_trigger_transition()

func _is_player_moving_through() -> bool:
	var player = GameManager.player
	if player == null:
		return false
	
	var vel = player.velocity
	
	match direction:
		Direction.RIGHT:
			return vel.x > 10  # Moving right through right edge
		Direction.LEFT:
			return vel.x < -10  # Moving left through left edge
		Direction.DOWN:
			return vel.y > 10  # Moving down through bottom edge
		Direction.UP:
			return vel.y < -10  # Moving up through top edge
	
	return false

func _trigger_transition() -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	transition_started.emit()
	
	var player = GameManager.player
	if player == null:
		is_transitioning = false
		return
	
	# Pause player input during transition
	GameManager.paused = true
	
	# Fade out
	await GameManager.fade_to_black(transition_duration)
	
	# Calculate new player position
	var new_position = _calculate_spawn_position()
	player.global_position = new_position
	player.velocity = Vector2.ZERO
	
	# Update camera bounds if target section has them
	if update_camera_bounds:
		_update_camera_to_section()
	
	# Fade in
	await GameManager.fade_from_black(transition_duration)
	
	# Resume player input
	GameManager.paused = false
	is_transitioning = false
	transition_completed.emit()

func _calculate_spawn_position() -> Vector2:
	# Find the matching transition in the target section
	if not target_transition_name.is_empty():
		var target_node = _find_target_transition()
		if target_node != null:
			# Spawn relative to target transition
			return target_node.global_position + _get_spawn_offset_for_direction(target_node.direction)
	
	# Fallback: use this transition's position + offset
	return global_position + spawn_offset

func _get_spawn_offset_for_direction(dir: Direction) -> Vector2:
	match dir:
		Direction.LEFT:
			return Vector2(-48, 0)  # Spawn to the left of left edge
		Direction.RIGHT:
			return Vector2(48, 0)   # Spawn to the right of right edge
		Direction.UP:
			return Vector2(0, -48)  # Spawn above top edge
		Direction.DOWN:
			return Vector2(0, 48)   # Spawn below bottom edge
	return Vector2.ZERO

func _find_target_transition() -> SectionTransition:
	# Search for target transition by name in the scene
	var root = get_tree().current_scene
	var transitions = root.find_children("*", "SectionTransition", true, false)
	
	for t in transitions:
		if t.name == target_transition_name and t != self:
			return t as SectionTransition
	
	return null

func _update_camera_to_section() -> void:
	var player = GameManager.player
	if player == null:
		return
	
	var camera = player.get_node_or_null("Camera2D")
	if camera == null:
		return
	
	# Try to get section bounds from target section
	if target_section != NodePath(""):
		var section = get_node_or_null(target_section)
		if section != null and section.has_method("get_camera_bounds"):
			var bounds = section.get_camera_bounds()
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

## Get the opposite direction (for finding matching transitions)
static func get_opposite_direction(dir: Direction) -> Direction:
	match dir:
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
		Direction.UP: return Direction.DOWN
		Direction.DOWN: return Direction.UP
	return Direction.RIGHT
