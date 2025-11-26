extends CanvasLayer
 
@onready var anim_sprite = $CenterContainer/ScrollAnimatedSprite
@onready var content_box = $CenterContainer/Control/ContentContainer
@onready var title_label = $CenterContainer/Control/LabelTitle
@onready var text_label = $CenterContainer/Control/ContentContainer/RichTextLabel
var is_closing: bool = false # Biến cờ để tránh người chơi bấm liên tục gây lỗi

func _ready():
	hide()
	# Quan trọng: UI phải chạy được khi game Pause
	process_mode = Node.PROCESS_MODE_ALWAYS 

func open(title: String, text: String):
	# 1. Setup nội dung	title_label.text = title
	title_label.text = title
	text_label.text = text
	
	# 2. Reset trạng thái
	content_box.hide() # Ẩn chữ đi
	anim_sprite.frame = 0 # Về frame đầu
	show() # Hiện UI tổng
	var screen_center = get_viewport().get_visible_rect().size / 2
	anim_sprite.global_position = screen_center
	
	get_tree().paused = true
	anim_sprite.play("open")
	# 3. Pause game
	get_tree().paused = true
	
	# 4. Chạy Animation mở giấy
	anim_sprite.play("open")
	
	# 5. Chờ diễn xong mới hiện chữ (Tạo hiệu ứng chữ hiện trên giấy)
	await anim_sprite.animation_finished
	
	# 6. Hiện chữ và nút đóng
	content_box.show()
	
	# (Optional) Thêm hiệu ứng fade in cho chữ cho mượt
	var tween = create_tween()
	content_box.modulate.a = 0
	tween.tween_property(content_box, "modulate:a", 1.0, 0.3)

func close():
	if is_closing: return # Nếu đang đóng dở thì không làm gì cả
	is_closing = true
	
	# Bước 1: Ẩn nội dung chữ ngay lập tức
	# (Nếu không ẩn, chữ sẽ lơ lửng kỳ cục khi tờ giấy thu nhỏ lại)
	content_box.hide()
	
	# Bước 2: Chạy animation ngược (Thu giấy vào)
	# "open" là tên animation mở của bạn, play_backwards sẽ tua ngược nó
	anim_sprite.play_backwards("open")
	
	# (Optional) Thêm âm thanh đóng giấy
	# $AudioStreamPlayer.play() 
	
	# Bước 3: Chờ animation chạy xong
	await anim_sprite.animation_finished
	
	# Bước 4: Ẩn toàn bộ UI và Trả lại game
	hide()
	get_tree().paused = false
	
	is_closing = false # Reset trạng thái
	

func _input(event: InputEvent) -> void:
	# Chỉ xử lý khi Popup đang hiện và chưa thực hiện đóng
	if not visible or is_closing:
		return

	# Kiểm tra các nút muốn dùng để tắt
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		
		# QUAN TRỌNG: Chặn input này lại, không cho nó lọt xuống nhân vật
		get_viewport().set_input_as_handled()
		
		close()
