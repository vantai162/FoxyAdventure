extends Area2D

# Biến này để bạn viết nội dung truyện ngay trong Inspector
@export_multiline var story_text: String = "..." 
@export var memory_title: String = "Ký ức số 1"

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is Player:
		# Gọi UI hiển thị truyện lên
		# Giả sử bạn có một UI toàn cục tên là StoryUI
		GameManager.show_story_popup(memory_title, story_text)
		
		# Hiệu ứng âm thanh nhặt đồ
		# body.play_sfx(...)
		
		# Xóa vật phẩm sau khi đọc xong (hoặc chỉ ẩn đi)
		queue_free()
