# Đặt script này lên node Area2D
extends Area2D
class_name TimerLever

# ----- Tín hiệu -----
signal lever_activated
signal lever_deactivated

# ----- Biến -----
# Thời gian hẹn giờ (bạn có thể chỉnh trong Inspector)
@export var duration: float = 3.0

# Biến trạng thái (private, không cho player tự tắt)
var _is_activated: bool = false
var player_is_near: bool = false

# ----- Node con bắt buộc -----
@onready var animated_sprite = $AnimatedSprite2D
@onready var timer = $Timer # Cần một node Timer là con

func _ready() -> void:
	# Cài đặt Timer
	timer.wait_time = duration
	timer.one_shot = true # Đảm bảo nó chỉ chạy 1 lần
	
	# Kết nối tín hiệu "timeout" của Timer với hàm tắt
	timer.timeout.connect(_on_timer_timeout)
	
	# Cập nhật animation lúc bắt đầu
	update_animation()

func _process(delta: float) -> void:
	# Chỉ kiểm tra input NẾU player đang ở gần
	if player_is_near and Input.is_action_just_pressed("interact"):
		activate_switch()

func activate_switch() -> void:
	# --- Đây là logic then chốt ---
	# 1. Nếu công tắc ĐÃ BẬT (đang đếm ngược), không làm gì cả
	if _is_activated:
		print("TIMER LEVER: Đang đếm ngược, vui lòng chờ...")
		return
		
	# 2. Nếu công tắc ĐANG TẮT, thì BẬT nó lên
	_is_activated = true
	update_animation()
	
	print("TIMER LEVER: ACTIVATED (Bắt đầu đếm 3s)")
	lever_activated.emit()
	
	# 3. Bắt đầu đếm ngược
	timer.start()

# Hàm này sẽ được gọi TỰ ĐỘNG khi Timer chạy hết 3 giây
func _on_timer_timeout() -> void:
	_is_activated = false
	update_animation()
	
	print("TIMER LEVER: DEACTIVATED (Hết giờ)")
	lever_deactivated.emit()

func update_animation() -> void:
	if _is_activated:
		animated_sprite.play("on")
	else:
		animated_sprite.play("off")

# --- Các hàm phát hiện Player (giữ nguyên) ---

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_is_near = true
	
func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_is_near = false
