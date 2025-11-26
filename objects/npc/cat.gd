extends Node2D # Hoặc Node2D tùy node gốc của bạn

# Tên Timeline Dialogic bạn muốn chạy cho NPC này
@export var timeline_name: String = "cat_timeline"

@onready var prompt_label = $Label

# Biến cờ để kiểm tra người chơi có đang ở gần không
var player_in_range: bool = false

func _ready():
	# Đảm bảo khi bắt đầu game label bị ẩn
	prompt_label.hide()
	$AnimatedSprite2D.play("idle")

# --- XỬ LÝ TÍN HIỆU AREA2D ---

# Khi có vật thể bước VÀO vùng cảm biến
func _on_interaction_zone_body_entered(body):
	# Kiểm tra xem có phải là Player không (dựa vào group ở Bước 2)
	if body.is_in_group("player"):
		prompt_label.show() # Hiện chữ "[F]"
		player_in_range = true # Bật cờ

# Khi có vật thể bước RA KHỎI vùng cảm biến
func _on_interaction_zone_body_exited(body):
	if body.is_in_group("player"):
		prompt_label.hide() # Ẩn chữ "[F]"
		player_in_range = false # Tắt cờ

# --- XỬ LÝ NÚT BẤM ---

func _input(event):
	# Điều kiện để kích hoạt hội thoại:
	# 1. Người chơi đang ở gần (player_in_range == true)
	# 2. Người chơi vừa bấm nút "interact" (phím F)
	# 3. Hiện tại KHÔNG có hội thoại nào đang chạy (tránh bấm F liên tục bị lỗi)
	if player_in_range and event.is_action_pressed("interact") and Dialogic.current_timeline == null:
		
		# Ẩn label đi cho đỡ vướng mắt khi đang thoại
		prompt_label.hide()
		
		# Bắt đầu Dialogic
		Dialogic.start(timeline_name)
		
		# Chặn input này lại, không cho nó truyền xuống Player
		# (Tránh việc bấm F vừa mở thoại vừa làm Player nhảy/đánh)
		get_viewport().set_input_as_handled()
