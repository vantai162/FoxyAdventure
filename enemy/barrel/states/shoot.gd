extends EnemyState

@export var burst_count: int = 3
@export var delay_between_shots: float = 0.75
@export var first_shot_delay: float = 0.5  # Time before first shot (sync with animation buildup)

var shots_fired: int = 0
var burst_timer: float = 0.0

func _enter() -> void:
	shots_fired = 0
	burst_timer = first_shot_delay
	obj.change_animation("shoot")  # Start shoot animation immediately for visual feedback

func _update(delta: float) -> void:
	burst_timer -= delta

	# When ready to fire and haven't fired all shots
	if burst_timer <= 0.0 and shots_fired < burst_count:
		fire_bullet()
		shots_fired += 1
		burst_timer = delay_between_shots

	# When all shots fired and delay passed
	if shots_fired >= burst_count and burst_timer <= 0.0:
		change_state(fsm.states.idle)

func fire_bullet() -> void:
	var bullet := obj.bullet_factory.create() as RigidBody2D
	bullet.global_position = obj.global_position
	bullet.apply_impulse(Vector2(obj.bullet_speed * obj.direction, 0))
