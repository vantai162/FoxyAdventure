@tool
extends Area2D
class_name SectionTransition

## Seamless transition trigger for moving between level sections
## Place at edges of sections - player walks through to transition
## Designer-friendly: set direction, target, and it just works
##
## IMPORTANT: The collision shape automatically adjusts based on direction!
## - LEFT/RIGHT transitions use a VERTICAL zone (tall and thin)
## - UP/DOWN transitions use a HORIZONTAL zone (wide and short)
## DO NOT rotate this node - change the direction property instead!

signal transition_started
signal transition_completed

enum Direction { LEFT, RIGHT, UP, DOWN }

@export_group("Transition Setup")
## Which direction the player exits through this transition.
## Shape automatically adjusts: LEFT/RIGHT = vertical, UP/DOWN = horizontal.
@export var direction: Direction = Direction.RIGHT:
	set(v):
		direction = v
		_update_shape_for_direction()
		_update_spawn_offset_for_direction()
		notify_property_list_changed()
		update_configuration_warnings()

@export var target_transition_name: String = ""  ## Name of matching transition in target (optional)
@export var target_section: NodePath  ## Optional: path to target LevelSection

@export_group("Timing")
@export var transition_duration: float = 0.3  ## Fade duration
@export var auto_trigger: bool = true  ## Trigger when player moves through
@export var trigger_threshold: float = 10.0  ## Minimum velocity to trigger

@export_group("Player Spawn")
## Offset from matching transition where player spawns.
## Auto-suggested based on direction, but can be customized.
@export var spawn_offset: Vector2 = Vector2(48, 0)

@export_group("Camera")
@export var update_camera_bounds: bool = true  ## Update camera to new section bounds

@export_group("Zone Size")
## Thickness of the trigger zone (perpendicular to transition direction)
@export var zone_thickness: float = 16.0:
	set(v):
		zone_thickness = v
		_update_shape_for_direction()

## Length of the trigger zone (parallel to transition direction)
@export var zone_length: float = 128.0:
	set(v):
		zone_length = v
		_update_shape_for_direction()

@export_group("Debug")
@export var show_debug: bool = false  ## Show trigger zone in editor

var is_transitioning: bool = false
var player_in_zone: bool = false

var _collision_shape: CollisionShape2D = null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	# Warn if node has rotation - this breaks direction logic!
	if not is_zero_approx(rotation) or not is_zero_approx(rotation_degrees):
		warnings.append("⚠️ This node has ROTATION applied!\nDO NOT rotate SectionTransition - change the 'direction' property instead.\nRotation breaks velocity detection and spawn offset calculations.")
	
	# Warn if scale is not uniform
	if not is_equal_approx(scale.x, 1.0) or not is_equal_approx(scale.y, 1.0):
		warnings.append("⚠️ This node has SCALE applied!\nUse 'zone_thickness' and 'zone_length' properties instead of scaling.")
	
	# Warn about spawn_offset mismatch with direction
	var expected_offset = _get_expected_spawn_offset()
	if spawn_offset.sign() != expected_offset.sign() and spawn_offset != Vector2.ZERO:
		warnings.append("ℹ️ spawn_offset direction may not match transition direction.\nExpected offset direction: %s\nCurrent: %s" % [expected_offset.sign(), spawn_offset.sign()])
	
	return warnings


func _ready() -> void:
	# Cache collision shape reference
	_collision_shape = $CollisionShape2D if has_node("CollisionShape2D") else null
	
	# Runtime-only connections
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
		
		# Ensure collision layer setup
		collision_layer = 0
		collision_mask = 2  # Player layer
	
	_update_shape_for_direction()
	
	if show_debug and has_node("DebugSprite"):
		$DebugSprite.visible = true


func _update_shape_for_direction() -> void:
	## Update collision shape size based on direction (works in editor and runtime)
	if _collision_shape == null:
		if has_node("CollisionShape2D"):
			_collision_shape = $CollisionShape2D
		else:
			return
	
	if _collision_shape.shape == null:
		return
	
	var shape = _collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision_shape.shape = shape
	else:
		# Make shape unique to prevent cross-instance pollution
		if not shape.resource_local_to_scene:
			var unique_shape = shape.duplicate()
			unique_shape.resource_local_to_scene = true
			_collision_shape.shape = unique_shape
			shape = unique_shape
	
	# Size based on direction:
	# LEFT/RIGHT = vertical zone (thin width, tall height)
	# UP/DOWN = horizontal zone (wide width, thin height)
	match direction:
		Direction.LEFT, Direction.RIGHT:
			shape.size = Vector2(zone_thickness, zone_length)
		Direction.UP, Direction.DOWN:
			shape.size = Vector2(zone_length, zone_thickness)


func _update_spawn_offset_for_direction() -> void:
	## Suggest appropriate spawn offset based on direction
	## Only auto-update if it looks like the default value
	var current_magnitude = spawn_offset.length()
	if current_magnitude < 1.0 or is_equal_approx(current_magnitude, 48.0):
		spawn_offset = _get_expected_spawn_offset()


func _get_expected_spawn_offset() -> Vector2:
	## Get the expected spawn offset for current direction
	match direction:
		Direction.RIGHT:
			return Vector2(48, 0)   # Spawn to the right of exit
		Direction.LEFT:
			return Vector2(-48, 0)  # Spawn to the left of exit
		Direction.DOWN:
			return Vector2(0, 48)   # Spawn below the exit
		Direction.UP:
			return Vector2(0, -48)  # Spawn above the exit
	return Vector2(48, 0)

func _physics_process(_delta: float) -> void:
	# Skip physics in editor
	if Engine.is_editor_hint():
		return
	
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
