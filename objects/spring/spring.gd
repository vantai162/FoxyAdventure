@tool
extends Area2D
## Spring/Trampoline that launches player and enemies
## Launches in the direction the spring faces based on orientation
## 
## @tool script - orientation updates immediately in editor

enum Orientation {
	FLOOR,    ## Spring on floor, launches UP (default)
	CEILING,  ## Spring on ceiling, launches DOWN
	LEFT,     ## Spring on left wall, launches RIGHT
	RIGHT     ## Spring on right wall, launches LEFT
}

## Launch directions for each orientation (where entities get launched TO)
const LAUNCH_DIRECTIONS := {
	Orientation.FLOOR: Vector2(0, -1),    # Launch UP
	Orientation.CEILING: Vector2(0, 1),   # Launch DOWN
	Orientation.LEFT: Vector2(1, 0),      # Launch RIGHT
	Orientation.RIGHT: Vector2(-1, 0)     # Launch LEFT
}

@export var orientation := Orientation.FLOOR:
	set(value):
		orientation = value
		_apply_orientation()

@export var launch_force: float = 650.0  ## Force applied when launching

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Rotation angles for each orientation
const ROTATIONS := {
	Orientation.FLOOR: 0.0,
	Orientation.CEILING: PI,
	Orientation.LEFT: PI / 2,
	Orientation.RIGHT: -PI / 2
}

func _apply_orientation() -> void:
	if not is_inside_tree():
		return
	rotation = ROTATIONS.get(orientation, 0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		call_deferred("_apply_orientation")

func _ready() -> void:
	_apply_orientation()
	
	# Don't run gameplay logic in editor
	if Engine.is_editor_hint():
		return



func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemy"):
		animated_sprite.play("jump")
		
		# Get launch direction based on orientation
		var launch_dir: Vector2 = LAUNCH_DIRECTIONS.get(orientation, Vector2(0, -1))
		
		# Apply velocity in the correct direction
		if body.has_method("spring_launch"):
			# Use directional launch if available
			body.spring_launch(launch_dir * launch_force)
		else:
			# Fallback: apply velocity directly
			body.velocity = launch_dir * launch_force
		
		AudioManager.play_sound("power_up", 20.0)


func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "jump":
		animated_sprite.play("idle")
