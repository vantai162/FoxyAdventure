extends RigidBody2D
class_name KingCrabCoconut

## King Crab's coconut projectile - bouncy physics, despawns after timeout or ground hit count

@export var bounce_count_limit: int = 3  ## Despawn after this many ground bounces
@export var lifetime: float = 5.0  ## Max lifetime in seconds

var _bounce_count: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Start lifetime timer
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func launch(start_velocity: Vector2) -> void:
	linear_velocity = start_velocity


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("ground"):
		_bounce_count += 1
		if _bounce_count >= bounce_count_limit:
			queue_free()


func _on_hit_area_2d_hitted() -> void:
	# Coconut hit player, despawn
	queue_free()
