extends CharacterBody2D

var physics_material_override = null 
# Biến check xem đã kích hoạt cutscene chưa để tránh bị lặp
var cutscene_started = false

# --- CẤU HÌNH ---
@export var move_speed: float = 40.0
@export var timeline_name: String = "captain_timeline"

# --- TRẠNG THÁI ---
enum State { IDLE, WALK }
var current_state = State.IDLE
var move_direction = 1 
var is_chatting = false        # Biến để kiểm tra xem có đang nói chuyện không
var player_in_range = false    # Biến kiểm tra Player có đứng gần không

# --- NODES ---
@onready var sprite = $AnimatedSprite2D
@onready var timer = $Timer
@onready var label = $Label    # ⚠️ Đảm bảo bạn đã tạo node Label trong Scene

func _ready():
	randomize()
	label.visible = false # Ẩn label khi bắt đầu game
	pick_new_state()

func _physics_process(delta):
	# Nếu đang nói chuyện thì không tính toán di chuyển nữa
	if is_chatting:
		return

	# 1. Trọng lực
	if not is_on_floor():
		velocity.y += 980 * delta
	
	# 2. Di chuyển
	if current_state == State.WALK:
		velocity.x = move_direction * move_speed
		if move_direction > 0:
			sprite.flip_h = false 
		else:
			sprite.flip_h = true  
		sprite.play("run")
	else:
		velocity.x = 0
		sprite.play("idle")

	move_and_slide()

# --- XỬ LÝ NÚT BẤM (INPUT) ---
func _input(event):
	# Kiểm tra: Nếu Player trong vùng VÀ nhấn phím Q VÀ chưa nói chuyện
	if player_in_range and not is_chatting:
		if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
			interact()

# --- CÁC TÍN HIỆU TỪ DETECTION AREA (Cần nối trong Editor) ---
# Khi Player bước vào vùng
func _on_detection_area_body_entered(body):
	if body.is_in_group("player"): # Hoặc body.is_in_group("Player")
		player_in_range = true
		if not is_chatting:
			label.visible = true # Hiện chữ "Nhấn Q"

# Khi Player rời khỏi vùng
func _on_detection_area_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		label.visible = false # Ẩn chữ

# --- AI LOGIC ---
func pick_new_state():
	if is_chatting: return # Đang nói thì không đổi trạng thái

	if randi() % 2 == 0:
		current_state = State.IDLE
		timer.wait_time = randf_range(3.0, 6.0)
	else:
		current_state = State.WALK
		move_direction = [-1, 1].pick_random()
		timer.wait_time = randf_range(2.0, 4.0)
	timer.start()

func _on_timer_timeout():
	pick_new_state()

# --- TƯƠNG TÁC ---
func interact():
	print("Captain: Bắt đầu hội thoại!")
	
	is_chatting = true       # Đánh dấu đang nói chuyện
	label.visible = false    # Ẩn dòng chữ "Nhấn Q" đi cho đỡ vướng
	
	# Dừng di chuyển
	current_state = State.IDLE
	velocity = Vector2.ZERO
	sprite.play("idle")
	timer.stop()
	var player = get_tree().get_first_node_in_group("player")
	player.set_physics_process(false)
	if player.has_method("stop_move"): player.stop_move()
	
	# Bắt đầu Dialogic
	Dialogic.start(timeline_name)
	Dialogic.timeline_ended.connect(_on_dialog_finished)

func _on_dialog_finished():
	Dialogic.timeline_ended.disconnect(_on_dialog_finished)
	
	# Thay vì cho Captain đi tiếp, ta kích hoạt Cutscene
	start_dramatic_ending()

# --- HÀM CUTSCENE: CƠN BÃO TẬN THẾ (Ultra Cinematic Version) ---
func start_dramatic_ending():
	if cutscene_started: return
	cutscene_started = true
	
	print(">>> BẮT ĐẦU CINEMATIC TẬN THẾ <<<")
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Lỗi: Không tìm thấy Player!")
		return

	# Khóa điều khiển
	player.set_physics_process(false)
	if player.has_method("stop_move"): player.stop_move()
	
	# === TẠO CÁC LAYER HIỆU ỨNG ===
	var sky_modulate = CanvasModulate.new()
	sky_modulate.color = Color(0.8, 0.8, 0.8, 1)
	get_tree().current_scene.add_child(sky_modulate)
	
	# Tạo overlay để làm hiệu ứng vignette + flash - CẦN CANVASLAYER
	var overlay_canvas = CanvasLayer.new()
	overlay_canvas.layer = 100
	get_tree().current_scene.add_child(overlay_canvas)
	
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_canvas.add_child(overlay)
	
	# Tạo layer nước (sóng dâng lên) - CẦN CANVASLAYER ĐỂ HIỂN THỊ
	var water_canvas = CanvasLayer.new()
	water_canvas.layer = 99
	get_tree().current_scene.add_child(water_canvas)
	
	var water_overlay = ColorRect.new()
	water_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	water_overlay.color = Color(0.05, 0.15, 0.35, 0) # Xanh dương nước biển, trong suốt ban đầu
	water_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water_canvas.add_child(water_overlay)
	
	var cam = null
	if player.has_node("Camera2D"):
		cam = player.get_node("Camera2D")
	
	# === ACT 1: THE CALM BEFORE THE STORM (3s) ===
	print("Act 1: Sự tĩnh lặng đáng sợ...")
	
	# Slow zoom in dramatic
	if cam:
		var zoom_in = create_tween().set_parallel(true)
		zoom_in.tween_property(cam, "zoom", Vector2(1.3, 1.3), 3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		
		# Trời tối dần + màu xanh lạnh lẽo (horror ambiance)
		var dark_ambiance = create_tween()
		dark_ambiance.tween_property(sky_modulate, "color", Color(0.15, 0.2, 0.35, 1), 3.0)
		
		# Vignette effect (tối viền màn hình)
		var vignette = create_tween()
		vignette.tween_property(overlay, "color", Color(0, 0, 0, 0.4), 3.0)
	
	await get_tree().create_timer(3.0).timeout

	# === ACT 2: THE WARNING (Sóng đầu tiên - 1.5s) ===
	print("Act 2: Sóng cảnh báo!")
	
	# Rung nhẹ + flash warning (vàng nhạt)
	overlay.color = Color(1, 1, 0.5, 0.3)
	var warning_fade = create_tween()
	warning_fade.tween_property(overlay, "color", Color(0, 0, 0, 0.4), 0.3)
	
	if cam and cam.has_method("shake_tsunami"):
		cam.shake_tsunami(20.0, 1.5) # Tăng độ rung
		
		# Nghiêng nhẹ sang trái (tàu bị sóng đánh lần 1)
		var tilt_warn = create_tween()
		tilt_warn.tween_property(cam, "rotation_degrees", -5.0, 0.5).set_trans(Tween.TRANS_BOUNCE)
		tilt_warn.tween_property(cam, "rotation_degrees", 0.0, 1.0)
	
	await get_tree().create_timer(1.5).timeout

	# === ACT 3: THE IMPACT - SÓNG THẦN ĐÁNH (2.5s) ===
	print("Act 3: SÓNG THẦN")
	
	# TRIPLE FLASH (White -> Blue -> Black)
	$"../Thunder".play()
	for i in range(3):
		overlay.color = Color(5, 5, 5, 1) # Trắng chói
		await get_tree().create_timer(0.08).timeout
		overlay.color = Color(0.1, 0.3, 0.8, 0.7) # Xanh nước biển
		await get_tree().create_timer(0.08).timeout
	
	# Camera shake CỰC MẠNH + Rotation CHAOS
	if cam:
		if cam.has_method("shake_tsunami"):
			cam.shake_tsunami(100.0, 2.5) # RUNG CỰC MẠNH!!!
		
		# Xoay camera điên cuồng (tàu lật)
		var chaos_rotation = create_tween()
		chaos_rotation.tween_property(cam, "rotation_degrees", 40.0, 0.3).set_trans(Tween.TRANS_CUBIC)
		chaos_rotation.tween_property(cam, "rotation_degrees", -25.0, 0.4).set_trans(Tween.TRANS_ELASTIC)
		chaos_rotation.tween_property(cam, "rotation_degrees", 20.0, 0.5)
		
		# Zoom ra để thấy quy mô thảm họa
		var panic_zoom = create_tween()
		panic_zoom.tween_property(cam, "zoom", Vector2(0.7, 0.7), 0.5).set_trans(Tween.TRANS_EXPO)
	
	# Màn hình tối thấm (underwater effect)
	sky_modulate.color = Color(0.05, 0.1, 0.15, 1)
	
	# Player chỉ rung lắc tại chỗ (không bay đi lung tung)
	#if player.has_method("play_animation"): 
	player.die()
	
	await get_tree().create_timer(2.5).timeout

	# === ACT 4: NƯỚC BIỂN DÂN LÊN (Water Rising - 3s) ===
	print("Act 4: Nước biển nhấn chìm mọi thứ...")
	
	# Slow motion effect (time distortion)
	Engine.time_scale = 0.4 # Làm chậm game
	
	# NƯỚC DÂN LÊN TỪ DƯỚI (hiệu ứng chính)
	# Tạo hiệu ứng nước tràn ngập từ dưới lên trên
	var water_rise = create_tween().set_parallel(true)
	water_rise.tween_property(water_overlay, "color:a", 0.85, 3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Fade to deep blue (underwater atmosphere)
	var drown_color = create_tween()
	drown_color.tween_property(sky_modulate, "color", Color(0.02, 0.05, 0.15, 1), 3.0)
	
	# Vignette tăng dần (mất ý thức)
	var blackout = create_tween()
	blackout.tween_property(overlay, "color", Color(0, 0, 0, 0.7), 3.0)
	
	# Camera zoom in lần cuối (POV chìm xuống)
	if cam:
		var final_zoom = create_tween()
		final_zoom.tween_property(cam, "zoom", Vector2(1.8, 1.8), 3.0).set_trans(Tween.TRANS_SINE)
		final_zoom.tween_property(cam, "rotation_degrees", 0.0, 3.0) # Về lại thẳng
	
	await get_tree().create_timer(3.0).timeout
	Engine.time_scale = 1.0 # Reset time
	
	# === ACT 5: UNDERWATER SILENCE (Hư vô - 3s) ===
	print("Act 5: Tĩnh lặng dưới đáy đại dương...")
	
	# Nước phủ kín hoàn toàn + FADE TO BLACK
	var final_drown = create_tween().set_parallel(true)
	final_drown.tween_property(water_overlay, "color", Color(0, 0, 0.1, 1), 2.0)
	final_drown.tween_property(overlay, "color", Color(0, 0, 0, 1), 2.5)
	
	await get_tree().create_timer(3.0).timeout
	
	# === ACT 6: TRANSITION (0.5s) ===
	print("Kết thúc.")
	
	if player.has_method("die"):
		player.die()
	
	# Cleanup
	overlay_canvas.queue_free()
	water_canvas.queue_free()
	sky_modulate.queue_free()
	
	get_tree().change_scene_to_file("res://scenes/game_screen/main_menu.tscn")
