@tool
extends Area2D
## Spring/Trampoline that launches player and enemies
## 
## @tool script - orientation updates immediately in editor

enum Orientation {
	FLOOR,    ## Spring on floor, launches up (default)
	CEILING,  ## Spring on ceiling, launches down
	LEFT,     ## Spring on right wall, launches left
	RIGHT     ## Spring on left wall, launches right
}

@export var orientation := Orientation.FLOOR:
	set(value):
		orientation = value
		_apply_orientation()

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
		body.spring()
		AudioManager.play_sound("power_up",20.0)


func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "jump":
		animated_sprite.play("idle")
