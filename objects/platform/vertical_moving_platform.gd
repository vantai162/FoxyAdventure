extends AnimatableBody2D

@export var move_speed: float = 100.0
@export var move_distance: float = 200.0
@export var acceleration: float = 300.0
@export var change_direction_time: float = 2.5

@onready var timer: Timer = $Timer

var velocity: float = 0.0
var direction: int = 1  # bắt đầu sang phải
var start_position: Vector2

func _ready():
	start_position = global_position
	timer.timeout.connect(_on_timer_timeout)
	timer.start(change_direction_time)

func _on_timer_timeout():
	direction *= -1  # đảo hướng
	timer.start(change_direction_time)  # tiếp tục đếm để đảo chiều lần sau

func _physics_process(delta):
	# Tính vận tốc hướng tới tốc độ mục tiêu
	var target_velocity = move_speed * direction
	velocity = move_toward(velocity, target_velocity, acceleration * delta)
	
	# Cập nhật vị trí
	global_position.y += velocity * delta

	
