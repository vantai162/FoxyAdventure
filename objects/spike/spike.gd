@tool
extends Node2D
class_name Spike
## Static spike hazard with editor-configurable orientation
## 
## Uses @tool to update visual in editor immediately when orientation changes.
## Collision shape adjusts automatically based on orientation.

enum Orientation {
	FLOOR,    ## Spike pointing up (default)
	CEILING,  ## Spike pointing down
	LEFT,     ## Spike pointing left (on right wall)
	RIGHT     ## Spike pointing right (on left wall)
}

@export var orientation := Orientation.FLOOR:
	set(value):
		orientation = value
		_apply_orientation()

@export var damage: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_area: Area2D = $HitArea2D
@onready var collision_shape: CollisionShape2D = $HitArea2D/CollisionShape2D

# Rotation angles for each orientation
const ROTATIONS := {
	Orientation.FLOOR: 0.0,
	Orientation.CEILING: PI,  # 180 degrees
	Orientation.LEFT: PI / 2,  # 90 degrees
	Orientation.RIGHT: -PI / 2  # -90 degrees
}

# Collision shape offsets for each orientation (based on spike texture shape)
# These position the hitbox at the pointy end
const COLLISION_OFFSETS := {
	Orientation.FLOOR: Vector2(0, 10.5),
	Orientation.CEILING: Vector2(0, -10.5),
	Orientation.LEFT: Vector2(-10.5, 0),
	Orientation.RIGHT: Vector2(10.5, 0)
}

# Collision shape sizes for each orientation
const COLLISION_SIZES := {
	Orientation.FLOOR: Vector2(29, 13),
	Orientation.CEILING: Vector2(29, 13),
	Orientation.LEFT: Vector2(13, 29),
	Orientation.RIGHT: Vector2(13, 29)
}


func _ready() -> void:
	_apply_orientation()
	
	# Set damage on HitArea2D if it has the property
	if hit_area and hit_area.has_method("set") and "damage" in hit_area:
		hit_area.damage = damage


func _apply_orientation() -> void:
	# Guard for editor when nodes aren't ready yet
	if not is_inside_tree():
		return
	
	# Apply rotation to sprite
	if sprite:
		sprite.rotation = ROTATIONS.get(orientation, 0.0)
	
	# Adjust collision shape
	if collision_shape:
		collision_shape.position = COLLISION_OFFSETS.get(orientation, Vector2.ZERO)
		
		# Resize the shape
		var shape = collision_shape.shape
		if shape is RectangleShape2D:
			shape.size = COLLISION_SIZES.get(orientation, Vector2(29, 13))


# Editor notification to apply when scene loads in editor
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		# Defer to ensure nodes are ready
		call_deferred("_apply_orientation")
