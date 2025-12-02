extends CanvasLayer

signal finished 

@onready var black_fade = $BlackFade
@onready var eyelid_rect = $EyelidRect
@onready var blur_rect = $BlurRect

# Biến để lưu Camera của Player
var player_cam: Camera2D

func _ready():
	start_sequence()

func start_sequence():
	var player = GameManager.player
	if not player: 
		emit_signal("finished")
		queue_free()
		return

	# --- 1. SETUP ---
	#player.is_locked = true
	player.visible = true
	if player.has_method("change_animation"):
		player.change_animation("dead")
	
	# Lấy camera để làm hiệu ứng chóng mặt
	if player.has_node("Camera2D"):
		player_cam = player.get_node("Camera2D")
		player_cam.zoom = Vector2(1.4, 1.4) # Zoom sát mặt ngay từ đầu
	
	visible = true
	black_fade.color.a = 1.0
	set_eyelid(0.0)
	set_blur(0.0)
	
	# --- 2. DIỄN XUẤT TỰ NHIÊN ---
	
	# Giai đoạn 0: Tỉnh dậy trong bóng tối (Chỉ nghe tiếng sóng)
	await get_tree().create_timer(1.5).timeout
	player.change_animation("dead")	
	# Fade out màn đen
	create_tween().tween_property(black_fade, "color:a", 0.0, 2.0)
	
	# Bắt đầu hiệu ứng "Camera Thở" (Mô phỏng đầu óc quay cuồng)
	start_breathing_camera()
	
	# Giai đoạn 1: Hé mắt nhìn (Thất bại)
	# Mắt mở hé ra rồi nhắm lại ngay vì mệt
	set_blur(5.0) # Rất mờ
	var t1 = create_tween()
	t1.tween_method(set_eyelid, 0.0, 0.2, 1.0).set_trans(Tween.TRANS_SINE) # Mở chậm
	await t1.finished
	
	var t1_close = create_tween()
	t1_close.tween_method(set_eyelid, 0.2, 0.0, 0.3) # Nhắm nhanh
	await t1_close.finished
	
	await get_tree().create_timer(0.8).timeout # Nghỉ một chút
	
	# Giai đoạn 2: Cố mở mắt lần nữa
	var t2 = create_tween()
	t2.tween_method(set_eyelid, 0.0, 0.5, 1.2) # Mở 50%
	t2.parallel().tween_method(set_blur, 5.0, 2.0, 1.2) # Bớt mờ chút
	await t2.finished
	
	# Nhấp nháy nhẹ (Blink)
	create_tween().tween_method(set_eyelid, 0.5, 0.3, 0.1) # Hơi khép
	await get_tree().create_timer(0.1).timeout
	create_tween().tween_method(set_eyelid, 0.3, 0.6, 0.2) # Mở lại
	
	await get_tree().create_timer(1.0).timeout
	
	# Giai đoạn 3: Tỉnh hẳn
	var t3 = create_tween()
	t3.tween_method(set_eyelid, 0.6, 1.0, 1.0) # Mở hết
	t3.parallel().tween_method(set_blur, 2.0, 0.0, 2.0) # Hết mờ
	# Trả Camera về bình thường
	if player_cam:
		t3.parallel().tween_property(player_cam, "zoom", Vector2(1.0, 1.0), 2.0)
		t3.parallel().tween_property(player_cam, "rotation", 0.0, 2.0) # Trả góc xoay về 0
	
	await t3.finished
	
	# --- 3. KẾT THÚC ---
	# Foxy đứng dậy
	player.change_animation("dead")
	
	await get_tree().create_timer(1.0).timeout
	
#	player.is_locked = false
	emit_signal("finished")
	queue_free()

# Hàm tạo hiệu ứng đầu óc quay cuồng
func start_breathing_camera():
	if not player_cam: return
	
	# Tạo vòng lặp zoom ra vào nhẹ nhàng + Nghiêng nhẹ
	var breath_tween = create_tween().set_loops(4) # Lặp 4 lần thôi rồi dừng
	breath_tween.tween_property(player_cam, "zoom", Vector2(1.45, 1.45), 2.0).set_trans(Tween.TRANS_SINE)
	breath_tween.parallel().tween_property(player_cam, "rotation", 0.02, 2.0) # Nghiêng phải tí
	
	breath_tween.tween_property(player_cam, "zoom", Vector2(1.4, 1.4), 2.0).set_trans(Tween.TRANS_SINE)
	breath_tween.parallel().tween_property(player_cam, "rotation", -0.02, 2.0) # Nghiêng trái tí

func set_eyelid(val): 
	if eyelid_rect: eyelid_rect.material.set_shader_parameter("openness", val)
func set_blur(val): 
	if blur_rect: blur_rect.material.set_shader_parameter("amount", val)
