extends Area2D

# King Crab claw projectile - wraps around screen edges

@export var speed: float = 400.0
var target_position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var has_wrapped: bool = false
var lifetime: float = 0.0
var max_lifetime: float = 8.0

func _ready() -> void:
	# Aim toward target
	if target_position != Vector2.ZERO:
		var direction = (target_position - global_position).normalized()
		velocity = direction * speed

func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime > max_lifetime:
		queue_free()
		return
	
	# Move claw
	global_position += velocity * delta
	
	# Screen wrap logic
	var screen_size = get_viewport_rect().size
	var wrapped: bool = false
	
	if global_position.x < 0:
		global_position.x = screen_size.x
		wrapped = true
	elif global_position.x > screen_size.x:
		global_position.x = 0
		wrapped = true
	
	if global_position.y < 0:
		global_position.y = screen_size.y
		wrapped = true
	elif global_position.y > screen_size.y:
		global_position.y = 0
		wrapped = true
	
	if wrapped:
		has_wrapped = true
		# After wrapping, return to boss position
		var boss = get_tree().get_first_node_in_group("king_crab")
		if boss:
			var return_dir = (boss.global_position - global_position).normalized()
			velocity = return_dir * speed

func _on_hit_area_2d_hitted(_area: Variant) -> void:
	# Check if hit coconut tree
	var parent = _area.get_parent()
	if parent and parent.is_in_group("coconut_tree"):
		_drop_coconuts_from_tree(parent)
	queue_free()

func _drop_coconuts_from_tree(tree: Node2D) -> void:
	# Spawn 2-3 coconuts from tree
	var coconut_scene = preload("res://projectiles/coconut.tscn")
	for i in range(randi_range(2, 3)):
		var coconut = coconut_scene.instantiate()
		get_tree().root.add_child(coconut)
		coconut.global_position = tree.global_position + Vector2(randf_range(-20, 20), 0)
		coconut.linear_velocity = Vector2(randf_range(-150, 150), -200)

func _on_body_entered(_body: Node) -> void:
	if _body.is_in_group("player"):
		queue_free()
