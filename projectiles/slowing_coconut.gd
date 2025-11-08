extends CoconutProjectile
class_name SlowingCoconut

@export var slow_puddle_scene: PackedScene

func _ready() -> void:
	if has_node("LifetimeTimer"):
		$LifetimeTimer.timeout.disconnect(queue_free)
		$LifetimeTimer.timeout.connect(_on_lifetime_timeout)

func _on_lifetime_timeout() -> void:
	if not slow_puddle_scene:
		queue_free()
		return
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, 500)
	)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	var spawn_position = global_position
	
	if result:
		spawn_position = result.position
	
	var slow_area = slow_puddle_scene.instantiate()
	get_tree().current_scene.add_child(slow_area)
	slow_area.global_position = spawn_position
	
	queue_free()
