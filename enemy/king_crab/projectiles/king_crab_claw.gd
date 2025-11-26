extends Area2D

## King Crab claw projectile - travels toward target, wraps around screen, then returns to boss

@export var speed: float = 400.0
var target_position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var has_wrapped: bool = false
var lifetime: float = 0.0
var max_lifetime: float = 8.0
var _initialized: bool = false


func _physics_process(delta: float) -> void:
	# Initialize direction on first frame (after target_position is set)
	if not _initialized and target_position != Vector2.ZERO:
		var direction = (target_position - global_position).normalized()
		velocity = direction * speed
		_initialized = true
	
	lifetime += delta
	if lifetime > max_lifetime:
		queue_free()
		return
	
	# Move claw
	global_position += velocity * delta
	
	# Screen wrap logic - use camera bounds if available, otherwise viewport
	var camera = get_viewport().get_camera_2d()
	var screen_rect: Rect2
	if camera:
		var half_size = get_viewport_rect().size / 2 / camera.zoom
		screen_rect = Rect2(camera.global_position - half_size, half_size * 2)
	else:
		screen_rect = get_viewport_rect()
	
	var wrapped: bool = false
	
	if global_position.x < screen_rect.position.x:
		global_position.x = screen_rect.end.x
		wrapped = true
	elif global_position.x > screen_rect.end.x:
		global_position.x = screen_rect.position.x
		wrapped = true
	
	if global_position.y < screen_rect.position.y:
		global_position.y = screen_rect.end.y
		wrapped = true
	elif global_position.y > screen_rect.end.y:
		global_position.y = screen_rect.position.y
		wrapped = true
	
	if wrapped and not has_wrapped:
		has_wrapped = true
		# After wrapping, return to boss position
		var boss = get_tree().get_first_node_in_group("king_crab")
		if boss:
			var return_dir = (boss.global_position - global_position).normalized()
			velocity = return_dir * speed


func _on_hit_area_2d_hitted(_area: Variant) -> void:
	queue_free()


func _on_body_entered(_body: Node) -> void:
	if _body.is_in_group("player"):
		queue_free()
