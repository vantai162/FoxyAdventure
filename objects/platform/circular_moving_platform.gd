extends AnimatableBody2D

@export var radius: float = 130.0                # Bán kính quỹ đạo
@export var angular_speed: float = 1.0           # Tốc độ góc (radians/giây)
@export var clockwise: bool = true               # True = quay theo chiều kim đồng hồ
@export var start_angle_deg: float = 0.0         # Góc bắt đầu (độ)

var center_position: Vector2                     # Tâm quỹ đạo
var angle: float = 0.0                           # Góc hiện tại (radians)

func _ready():
	center_position = global_position             # Lưu lại tâm ban đầu
	angle = deg_to_rad(start_angle_deg)           # Chuyển độ sang radian

func _physics_process(delta):
	# Tăng góc mỗi frame
	var direction = -1 if clockwise else 1
	angle += angular_speed * direction * delta

	# Cập nhật vị trí platform
	global_position = center_position + Vector2(
		cos(angle) * radius,
		sin(angle) * radius
	)
