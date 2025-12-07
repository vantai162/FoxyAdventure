extends StaticBody2D

@export var break_delay: float = 0.6        # thời gian chờ trước khi vỡ (reduced from 1.0)
@export var shake_intensity: float = 4.0    # biên độ rung
@export var shake_speed: float = 0.05       # tốc độ rung
@export var disappear_time: float = 0.2     # thời gian biến mất (fade out)
@export var respawn_time: float = 3.5       # thời gian hồi sinh sau khi biến mất (reduced from 5.0)
@export var respawn_fade_time: float = 0.3  # thời gian fade in khi hồi sinh

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
	# Start invisible and fade in smoothly
	sprite.modulate.a = 0.0
	visible = true
	
	# Fade in effect to avoid "popping"
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, respawn_fade_time)
	await tween.finished
	
	# Enable collision after visual is fully visible
	collision.disabled = false
	detector.monitoring = true
	is_breaking = false
	is_respawning = false
	
func _on_interactive_area_2d_body_entered(body: Node2D) -> void:
	if is_breaking or is_respawning:
		return
	if body.is_in_group("player"):
		# Only trigger when player is actually standing on the platform
		# (on floor and moving downward or stationary, not jumping through)
		if body is CharacterBody2D:
			if not body.is_on_floor():
				return
			# Check player is above the platform (feet at or below detection zone)
			if body.velocity.y < -50:  # Player jumping upward, don't trigger
				return
		start_shake_and_break()
