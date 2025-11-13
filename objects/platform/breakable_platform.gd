extends StaticBody2D

@export var break_delay: float = 1.0        # thời gian chờ trước khi vỡ
@export var shake_intensity: float = 4.0    # biên độ rung
@export var shake_speed: float = 0.05       # tốc độ rung
@export var disappear_time: float = 0.2     # thời gian biến mất (fade out)

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var timer: Timer = $Timer

var original_position: Vector2
var is_breaking = false

func _ready():
	original_position = position
	timer.timeout.connect(_on_timer_timeout)

func start_shake_and_break():
	is_breaking = true
	timer.start(break_delay)
	shake_platform()

func shake_platform():
	var tween = create_tween()
	var count = int(break_delay / (shake_speed * 2))
	for i in count:
		tween.tween_property(self, "position", original_position + Vector2(randf_range(-shake_intensity, shake_intensity), 0), shake_speed)
		tween.tween_property(self, "position", original_position, shake_speed)

func _on_timer_timeout():
	break_platform()

func break_platform():
	# Tắt va chạm
	collision.disabled = true
	
	# Hiệu ứng fade out
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, disappear_time)
	
	await tween.finished
	queue_free()


func _on_interactive_area_2d_body_entered(body: Node2D) -> void:
	if not is_breaking:
		print("alo")
		start_shake_and_break()
