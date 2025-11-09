extends EnemyState

@export var burst_count: int = 3
@export var delay_between_shots: float = 0.75
@export var first_shot_delay: float = 0.7  # ⏱ Thời gian chờ trước khi bắn viên đầu tiên

var shots_fired: int = 0
var burst_timer: float = 0.0

func _enter() -> void:
	shots_fired = 0
	burst_timer = first_shot_delay  # ✅ Chờ 0.1 giây trước khi bắn viên đầu tiên
	obj.change_animation("idle")  # Animation chuẩn bị bắn

func _update(delta: float) -> void:
	burst_timer -= delta

	# Khi tới thời điểm bắn và chưa đủ số viên
	if burst_timer <= 0.0 and shots_fired < burst_count:
		obj.change_animation("shoot")
		fire_bullet()
		shots_fired += 1
		burst_timer = delay_between_shots  # reset timer giữa các viên

	# Khi bắn đủ số viên và đã qua delay cuối
	if shots_fired >= burst_count and burst_timer <= 0.0:
		change_state(fsm.previous_state)

func fire_bullet() -> void:
	var bullet := obj.bullet_factory.create() as RigidBody2D
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = obj.global_position
	bullet.apply_impulse(Vector2(obj.bullet_speed * obj.direction, 0))
