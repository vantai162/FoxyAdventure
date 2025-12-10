extends Node2D
class_name TargetIndicator
## Glowing dot with trail particles above targeted enemy's head.
## Auto-detects collision shape to position correctly for any enemy size.

## Margin above collision shape top
const MARGIN_ABOVE: float = 8.0
## Hover bob amplitude
const BOB_AMPLITUDE: float = 2.0
## Hover bob speed
const BOB_SPEED: float = 5.0

var _target: Node2D = null
var _time: float = 0.0
var _base_offset: Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	
	_time += delta
	var bob := sin(_time * BOB_SPEED) * BOB_AMPLITUDE
	global_position = _target.global_position + _base_offset + Vector2(0, bob)


## Attach to target, auto-positioning above their collision shape
func attach_to(target: Node2D, _offset: Vector2 = Vector2.ZERO) -> void:
	_target = target
	_base_offset = _calculate_head_offset(target)
	global_position = target.global_position + _base_offset
	# Start trail particles
	if has_node("TrailParticles"):
		$TrailParticles.emitting = true


## Find collision shape and calculate offset to top
func _calculate_head_offset(target: Node2D) -> Vector2:
	var shape_node := _find_collision_shape(target)
	if shape_node == null:
		return Vector2(0, -24)
	
	var shape := shape_node.shape
	var shape_offset := shape_node.position
	var top_y := 0.0
	
	if shape is RectangleShape2D:
		top_y = shape_offset.y - shape.size.y / 2.0
	elif shape is CapsuleShape2D:
		top_y = shape_offset.y - shape.height / 2.0
	elif shape is CircleShape2D:
		top_y = shape_offset.y - shape.radius
	else:
		top_y = shape_offset.y - 16.0
	
	return Vector2(0, top_y - MARGIN_ABOVE)


## Recursively find first CollisionShape2D
func _find_collision_shape(node: Node) -> CollisionShape2D:
	for child in node.get_children():
		if child is CollisionShape2D and child.shape != null:
			return child
		var found := _find_collision_shape(child)
		if found != null:
			return found
	return null


## Detach and fade out
func detach() -> void:
	_target = null
	# Stop trail and fade dot
	if has_node("TrailParticles"):
		$TrailParticles.emitting = false
	var tween := create_tween()
	tween.tween_property($Dot, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
	tween.tween_callback(queue_free)
