extends StaticBody2D

@export var break_delay: float = 1.0        # thời gian chờ trước khi vỡ
@export var shake_intensity: float = 4.0    # biên độ rung
@export var shake_speed: float = 0.05       # tốc độ rung
@export var disappear_time: float = 0.2     # thời gian biến mất (fade out)
@export var respawn_time: float = 5.0       # thời gian hồi sinh sau khi biến mất

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var timer: Timer = $Timer
@onready var detector: Area2D = $InteractiveArea2D

var original_position: Vector2
var is_breaking: bool = false
var is_respawning: bool = false

func _ready():
	original_position = position
	timer.timeout.connect(_on_timer_timeout)
	detector.body_entered.connect(_on_interactive_area_2d_body_entered)


func start_shake_and_break():
	print("loa")
	is_breaking = true
	timer.start(break_delay)
	shake_platform()

func shake_platform():
	var tween = create_tween()
	var count = max(1, int(break_delay / (shake_speed * 2)))
	for i in range(count):
		tween.tween_property(
			self, 
			"position", 
			original_position + Vector2(randf_range(-shake_intensity, shake_intensity), 0), 
			shake_speed
		)
		tween.tween_property(self, "position", original_position, shake_speed)

func _on_timer_timeout():
	break_platform()

func break_platform():
	collision.disabled = true
	detector.monitoring = false
	
	# Hiệu ứng fade out
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, disappear_time)
	await tween.finished

	# Ẩn platform
	visible = false
	position = original_position
	is_respawning = true
	# Chờ vài giây rồi hồi sinh
	await get_tree().create_timer(respawn_time).timeout
	respawn_platform()

func respawn_platform():
	visible = true
	collision.disabled = false
	detector.monitoring = true
	sprite.modulate.a = 1.0
	is_breaking = false
	is_respawning = false
	
func _on_interactive_area_2d_body_entered(body: Node2D) -> void:
	if is_breaking or is_respawning:
		return
	if body.is_in_group("player"):
		start_shake_and_break()
