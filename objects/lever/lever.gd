# Đặt script này trực tiếp lên node Area2D của bạn
extends Area2D
class_name Lever

# Biến để lưu trạng thái của cần gạt (đang bật hay tắt)
@export var is_activated: bool = false

signal lever_activated
signal lever_deactivated

# Biến để theo dõi xem player có đang ở gần không
var player_is_near: bool = false

func _ready() -> void:
	# Cập nhật animation lúc bắt đầu dựa trên trạng thái
	update_animation()

# Hàm _process chạy mỗi frame
func _process(delta: float) -> void:
	# Chỉ kiểm tra input NẾU player đang ở gần
	if player_is_near and Input.is_action_just_pressed("interact"):
		activate()

func activate() -> void:
	is_activated = not is_activated
	update_animation()

	if is_activated:
		print("ACTIVATED")
		lever_activated.emit()
	else:
		print("DEACTIVATED")
		lever_deactivated.emit()

func update_animation() -> void:
	if is_activated:
		$AnimatedSprite2D.play("on")
	else:
		$AnimatedSprite2D.play("off")

# Được gọi khi player (body) đi vào vùng Area2D
func _on_body_entered(body: Node2D) -> void:
	# Bạn nên kiểm tra xem body có phải là player không
	if body is Player:
		print("ACTIVATED")
		player_is_near = true
	
# Được gọi khi player (body) đi ra khỏi vùng Area2D
func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_is_near = false
