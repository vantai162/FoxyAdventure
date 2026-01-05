extends Node2D

# --- 1. KHAI BÁO NODE ---
@onready var global_light = $GlobalLight
@onready var cam = $Camera2D
@onready var bgm_player = $BGM_Player

# --- BACKGROUND & MÔI TRƯỜNG ---
@onready var sky_sprite = $GroundLayer/ParallaxBackground/ParallaxLayer/SkySprite2D
@onready var rain_rect = $BadEffects/ParallaxBackground/ParallaxLayerRain/CanvasLayer/ColorRect

# --- TEXTURE BẦU TRỜI ---
@export var bad_sky_texture: Texture2D 
var original_sky_texture: Texture2D 

# --- NHÓM HIỆU ỨNG & DIỄN VIÊN ---
@onready var bad_effects = $BadEffects
@onready var good_effects = $GoodEffects
@onready var leaf_particles = $GoodEffects/CanvasLayer

@onready var foxy_actor = $Actors/Foxy
# --- [NEW] FOXY SKINS ---
@onready var foxy_normal = $Actors/Foxy/Foxy_Normal
@onready var foxy_sinner = $Actors/Foxy/Foxy_Sinner

@onready var captain_npc = $Actors/Captain
@onready var hat_prop = $Actors/Hat
@onready var warlord_actor = $Actors/Warlord
@onready var king_crab = $Actors/KingCrab

# --- UI CINEMATIC ---
@onready var top_bar = $CinematicUI/TopBar
@onready var bot_bar = $CinematicUI/BottomBar

@onready var sea_sky_sprite = $ParallaxBackground/ParallaxLayer/SeaSkySprite2D
@onready var water_sprite = $ParallaxBackground/ParallaxLayer/WaterSprite2D

# --- CẤU HÌNH ---
var stop_distance = 80.0 
var recorded_ending_type: String = "GOOD" # [ADDED] Biến lưu loại ending để hiển thị Text

func _ready():
	if GameManager.current_stage: GameManager.current_stage.queue_free()
	
	if sky_sprite: original_sky_texture = sky_sprite.texture
	
	if rain_rect:
		rain_rect.modulate.a = 0.0 
		rain_rect.visible = false 
		if rain_rect.material:
			rain_rect.material.set_shader_parameter("rain_color", Color.WHITE)
			rain_rect.material.set_shader_parameter("rain_amount", 200.0)
	
	bad_effects.visible = false
	good_effects.visible = false
	if leaf_particles: leaf_particles.visible = false
	
	global_light.color = Color(0, 0, 0, 1)
	
	hat_prop.visible = true
	foxy_normal.visible = true
	foxy_sinner.visible = false

	foxy_normal.play("idle")
	foxy_sinner.play("idle")
	captain_npc.play("idle")
	king_crab.play("idle")
	
	captain_npc.flip_h = true 
	
	# Đặt Z-Index mặc định để tránh lỗi hiển thị
	foxy_actor.z_index = 1
	captain_npc.z_index = 1
	if warlord_actor:
		warlord_actor.visible = false
		warlord_actor.play("idle")
		warlord_actor.z_index = 0 
	
	open_cinematic_bars()
	Dialogic.signal_event.connect(_on_dialogic_signal)
	
	# --- [LOGIC CHECK ENDING MỚI] ---
	var final_ending_type = "GOOD" # Mặc định là Good
	#GameManager.add_kill()
	print("Current Kill Count: ", GameManager.kill_count)
	
	# Nếu giết quá 10 mạng -> BAD ENDING
	if GameManager.kill_count > 0:
		final_ending_type = "BAD"
		if GameManager.skin_manager and GameManager.skin_manager.cur_skin_data.has("SinnerFoxy"):
			GameManager.skin_manager.cur_skin_data["SinnerFoxy"].UnlockToBuy()
			GameManager.skin_manager._save_skin_data()
			print("Skin SinnerFoxy đã được unlock sau bad ending!")
	
	recorded_ending_type = final_ending_type # [ADDED] Lưu lại kết quả
	
	# Bắt đầu diễn hoạt theo kết quả đã check
	start_captain_entrance(final_ending_type)
	
func start_captain_entrance(type: String):
	# Foxy đứng sẵn
	foxy_normal.play("idle")
	foxy_sinner.play("idle")
	
	# Captain xuất hiện phía sau (ngoài màn hình)
	captain_npc.position = get_active_foxy().position + Vector2(-600, 0)
	captain_npc.flip_h = false
	captain_npc.play("walk")
	
	# Camera focus Foxy trước
	cam.position = get_active_foxy().position
	cam.zoom = Vector2(1.2, 1.2)
	
	await get_tree().create_timer(0.5).timeout
	
	# Captain đi tới gần Foxy
	var target_x = get_active_foxy().position.x - stop_distance
	var t = create_tween()
	t.tween_property(captain_npc, "position:x", target_x, 3.0)\
		.set_trans(Tween.TRANS_SINE)
	
	await t.finished
	
	captain_npc.play("idle")
	#captain_npc.flip_h = true
	
	# Camera focus cả hai
	var center_pos = (get_active_foxy().position + captain_npc.position) / 2
	focus_camera(center_pos, Vector2(1.5, 1.5), 1.5)
	
	await get_tree().create_timer(1.0).timeout
	
	# BẮT ĐẦU DIALOG
	start_dialog_by_type(type)


func start_dialog_by_type(type: String):
	if type == "BAD" or type == "BAD_ENDING":
		play_bad_scenario()
	else:
		play_good_scenario()

func open_cinematic_bars():
	if top_bar and bot_bar:
		top_bar.custom_minimum_size.y = 80
		bot_bar.custom_minimum_size.y = 80
		top_bar.position.y = -80
		bot_bar.position.y = get_viewport_rect().size.y
		var t = create_tween().set_parallel(true)
		t.tween_property(top_bar, "position:y", 0.0, 2.0).set_trans(Tween.TRANS_SINE)
		t.tween_property(bot_bar, "position:y", get_viewport_rect().size.y - 80, 2.0).set_trans(Tween.TRANS_SINE)

func start_opening_sequence(type: String):
	get_active_foxy().position.x = captain_npc.position.x - 300
	var center_pos = (get_active_foxy().position + captain_npc.position) / 2
	cam.position = center_pos
	cam.zoom = Vector2(1.2, 1.2)
	
	var t = create_tween()
	t.tween_property(global_light, "color", Color(0.2, 0.2, 0.2, 1), 1.0)
	
	await get_tree().create_timer(1.0).timeout
	
	foxy_normal.play("idle")
	foxy_sinner.play("idle")
	var walk_tween = create_tween()
	var target_x = captain_npc.position.x - stop_distance
	walk_tween.tween_property(get_active_foxy(), "position:x", target_x, 3.5).set_trans(Tween.TRANS_LINEAR)
	
	var cam_tween = create_tween()
	cam_tween.tween_property(cam, "position:x", target_x + 40, 3.5).set_trans(Tween.TRANS_SINE)
	
	await walk_tween.finished
	foxy_normal.play("idle")
	foxy_sinner.play("idle")
	
	focus_camera(captain_npc.position - Vector2(40, 0), Vector2(1.5, 1.5), 2.0)
	
	if type == "BAD" or type == "BAD_ENDING":
		play_bad_scenario()
	else:
		play_good_scenario() 

# --- SCENARIOS ---
func play_bad_scenario():
	bad_effects.visible = true
	if leaf_particles: leaf_particles.visible = false
	if rain_rect and rain_rect.material:
		rain_rect.visible = true
		create_tween().tween_property(rain_rect, "modulate:a", 1.0, 5.0)
	
	var gloomy_color = Color(0.6, 0.1, 0.1, 1.0)
	var t_env = create_tween().set_parallel(true)
	if sky_sprite:
		var t_sky = create_tween()
		t_sky.tween_property(sky_sprite, "modulate:a", 0.0, 2.0)
		t_sky.tween_callback(func(): 
			if bad_sky_texture: sky_sprite.texture = bad_sky_texture
			sky_sprite.modulate = Color(gloomy_color.r, gloomy_color.g, gloomy_color.b, 0.0) 
		)
		t_sky.tween_property(sky_sprite, "modulate:a", 1.0, 4.0)
	if sea_sky_sprite: t_env.tween_property(sea_sky_sprite, "modulate", gloomy_color, 6.0)
	if water_sprite: t_env.tween_property(water_sprite, "modulate", gloomy_color, 6.0)
	t_env.tween_property(global_light, "color", Color(0.7, 0.0, 0.0, 1), 6.0) 
	t_env.tween_property(global_light, "energy", 0.5, 6.0) 
	await get_tree().create_timer(6.0).timeout
	Dialogic.start("bad_ending_timeline")
	await get_tree().process_frame
	force_dialogic_on_top()

func play_good_scenario():
	good_effects.visible = true
	if leaf_particles: leaf_particles.visible = true
	if rain_rect:
		bad_effects.visible = false 
		var t_rain = create_tween()
		t_rain.tween_property(rain_rect, "modulate:a", 0.0, 1.0)
		t_rain.tween_callback(func(): rain_rect.visible = false)
	else:
		bad_effects.visible = false
	if sky_sprite and original_sky_texture:
		var t_sky = create_tween()
		t_sky.tween_property(sky_sprite, "modulate", Color.WHITE, 4.0)
		sky_sprite.texture = original_sky_texture
	var t = create_tween().set_parallel(true)
	t.tween_property(global_light, "color", Color(1.0, 0.95, 0.8, 1), 5.0)
	t.tween_property(global_light, "energy", 1.1, 5.0)
	await get_tree().create_timer(5.0).timeout
	Dialogic.start("good_ending_timeline")
	await get_tree().process_frame
	force_dialogic_on_top()
	
# --- SIGNAL HANDLERS ---
func _on_dialogic_signal(arg: String):
	match arg:
		"stop_music":
			create_tween().tween_property(bgm_player, "volume_db", -80, 1.0)
		"foxy_turn_around":
			foxy_normal.flip_h = true
			foxy_sinner.flip_h = true
		# [BAD ENDING] FOXY ĐỘI MŨ VÀ ĐI CÙNG CAPTAIN
		"foxy_wear_hat":
			# ===============================
			# [NEW] FOXY TRANSFORMATION
			# ===============================

			Engine.time_scale = 0.5
			focus_camera(get_active_foxy().position, Vector2(2.0, 2.0), 0.5)

			# Đội mũ biến mất
			hat_prop.visible = false

			# --- [NEW] ĐỔI SKIN ---
			foxy_normal.visible = false
			foxy_sinner.visible = true

			# Đồng bộ trạng thái
			foxy_sinner.position = foxy_normal.position
			foxy_sinner.flip_h = foxy_normal.flip_h
			foxy_sinner.z_index = foxy_normal.z_index

			# Animation sinner
			foxy_sinner.play("idle")

			# Hiệu ứng tà ác
			var t = create_tween()
			t.tween_property(foxy_sinner, "modulate", Color(2.0, 0.2, 0.2), 0.5)

			flash_screen(Color.RED)
			shake_camera(5.0)

			await get_tree().create_timer(1.0).timeout
			Engine.time_scale = 1.0
			
		"bad_walk_away":
			# Cả 2 cùng đi về phía bóng tối
			play_duo_walk_away()

		# [GOOD ENDING] WARLORD NHẢY TỪ TRÊN XUỐNG
		"warlord_arrive":
			var landing_pos_x = captain_npc.position.x + 80
			var landing_pos_y = captain_npc.position.y - 30
			
			warlord_actor.position = Vector2(landing_pos_x, landing_pos_y - 400)
			warlord_actor.visible = true
			warlord_actor.flip_h = false 
			warlord_actor.z_index = 0 
			
			var target_cam = captain_npc.position + Vector2(100, 0)
			focus_camera(target_cam, Vector2(1.2, 1.2), 0.5)
			
			var t = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(warlord_actor, "position:y", landing_pos_y, 0.6)
			
			await t.finished
			shake_camera(5.0)
			captain_npc.flip_h = false 

		# WARLORD GÂY ÁP LỰC
		"warlord_pressure":
			var center_fight = captain_npc.position
			focus_camera(center_fight, Vector2(1.1, 1.1), 0.5)
			
			var t = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			t.tween_property(warlord_actor, "position:x", warlord_actor.position.x - 30, 0.5)
			
			var t2 = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t2.tween_property(captain_npc, "position:x", captain_npc.position.x - 20, 0.3)
			
			shake_camera(2.0)

		# FOXY ĐÁNH LÉN (GOOD ENDING CLIMAX)
		"destroy_hat":
			Engine.time_scale = 0.5 
			
			foxy_normal.play("idle")
			foxy_sinner.play("idle")
			var t = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			var foxy = get_active_foxy()
			t.tween_property(foxy, "position:x", captain_npc.position.x - 50, 0.4)
			
			focus_camera(captain_npc.position, Vector2(2.5, 2.5), 0.4)
			
			await t.finished
			foxy_normal.flip_h = false
			foxy_sinner.flip_h = false
			foxy_normal.play("attack")
			foxy_sinner.play("attack")
			await get_tree().create_timer(0.2).timeout
			
			hat_prop.visible = false 
			
			captain_npc.play("hurt")
			captain_npc.flip_h = true
			captain_npc.modulate = Color(1, 0.5, 0.5)
			captain_npc.z_index = warlord_actor.z_index + 10 
			
			var t_hurt = create_tween()
			t_hurt.tween_property(captain_npc, "position:x", captain_npc.position.x + 40, 0.2)
			
			flash_screen(Color.GOLD)
			shake_camera(10.0)
			
			Engine.time_scale = 1.0 
			
			await get_tree().create_timer(1.0).timeout
			captain_npc.modulate = Color.WHITE
			captain_npc.play("idle") 
			foxy_normal.play("idle")
			foxy_sinner.play("idle")
			
			var surround_pos = captain_npc.position
			focus_camera(surround_pos, Vector2(1.3, 1.3), 1.0)
			
		"good_ending_scene":
			play_captain_flee()
			
		"credits":
			finish_game()

# --- UTILITIES ---
func focus_camera(target_pos: Vector2, zoom_val: Vector2, duration: float):
	var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(cam, "position", target_pos, duration)
	t.tween_property(cam, "zoom", zoom_val, duration)

func shake_camera(intensity: float):
	var original_offset = cam.offset
	var tween = create_tween()
	for i in range(10):
		var rand_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(cam, "offset", rand_offset, 0.05)
	tween.tween_property(cam, "offset", original_offset, 0.05)

func play_duo_walk_away():
	# BAD ENDING WALK
	focus_camera(cam.position, Vector2(1.0, 1.0), 4.0)

	# [CHANGED] dùng sinner foxy
	foxy_sinner.play("run")
	captain_npc.play("run")

	foxy_sinner.flip_h = false
	captain_npc.flip_h = false

	var t = create_tween().set_parallel(true)

	t.tween_property(foxy_sinner, "position:x", foxy_sinner.position.x + 800, 5.0)
	t.tween_property(captain_npc, "position:x", captain_npc.position.x + 800, 5.0)

	# Silhouette
	t.tween_property(foxy_sinner, "modulate", Color.BLACK, 4.0)
	t.tween_property(captain_npc, "modulate", Color.BLACK, 4.0)

func play_captain_flee():
	captain_npc.flip_h = false 
	captain_npc.play("walk")
	if captain_npc.sprite_frames.has_animation("walk"):
		captain_npc.speed_scale = 2.0 
	
	var t = create_tween()
	t.tween_property(captain_npc, "position:x", captain_npc.position.x + 1000, 2.0).set_trans(Tween.TRANS_LINEAR)
	t.parallel().tween_property(captain_npc, "modulate:a", 0.0, 2.0)
	
	await t.finished
	captain_npc.speed_scale = 1.0 
	
	#foxy_actor.flip_h = true 
	
	var center_final = (get_active_foxy().position + warlord_actor.position) / 2
	focus_camera(center_final, Vector2(1.5, 1.5), 2.0)

func flash_screen(color: Color):
	var flash = CanvasModulate.new()
	flash.color = color * 2
	add_child(flash)
	var t = create_tween()
	t.tween_property(flash, "color", Color(1,1,1,1), 0.5) 
	t.tween_callback(flash.queue_free)

func finish_game():
	print("Running Credits...")
	var screen_size = get_viewport_rect().size
	var half_height = screen_size.y / 2
	
	var t_cam = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t_cam.tween_property(cam, "position:y", cam.position.y - 400, 5.0) # Bay lên trời cao
	t_cam.tween_property(cam, "zoom", Vector2(0.8, 0.8), 5.0) # Zoom out xa
	
	if top_bar and bot_bar:
		var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(top_bar, "size:y", half_height, 3.0)
		t.tween_property(bot_bar, "position:y", half_height, 3.0)
		t.tween_property(bot_bar, "size:y", half_height, 3.0)
		t.tween_property(global_light, "color", Color.BLACK, 3.0)
		#t.tween_property(bgm_player, "volume_db", -80, 3.0)
		await t.finished
	
	if bad_effects.visible:
		bad_effects.visible = false
	
	# --- [ADDED] HIỆN TITLE ENDING TRƯỚC KHI CHẠY CHỮ ---
	await play_ending_title_card()
	# ----------------------------------------------------
		
	show_credits()

# --- [ADDED] HÀM HIỆN TEXT ENDING ---
func play_ending_title_card():
	var title_label = Label.new()
	
	# Cấu hình text
	if recorded_ending_type == "BAD":
		title_label.text = "- BAD ENDING -"
		title_label.modulate = Color(0.8, 0.0, 0.0, 0.0) # Đỏ thẫm, ẩn
	else:
		title_label.text = "- GOOD ENDING -"
		title_label.modulate = Color(1.0, 0.84, 0.0, 0.0) # Vàng kim, ẩn

	# Cấu hình Font và Vị trí
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64) 
	
	$CinematicUI.add_child(title_label)
	
	# Đặt giữa màn hình
	var screen_size = get_viewport_rect().size
	title_label.size = Vector2(screen_size.x, 200)
	title_label.position = Vector2(0, (screen_size.y / 2) - 100)
	
	# Animation Fade In -> Wait -> Fade Out
	var t = create_tween()
	t.tween_property(title_label, "modulate:a", 1.0, 2.0)
	t.tween_interval(2.0)
	t.tween_property(title_label, "modulate:a", 0.0, 1.5)
	
	await t.finished
	title_label.queue_free()

func show_credits():
	var credit_label = Label.new()
	credit_label.text = "FOXY ADVENTURE - Voyage of Oblivion\n\nFrom Group 10-UIT With Love\nHoàng Văn Tài\nVõ Trung Tín\nPhan Phú Thọ\nVõ Minh Tiến\nNguyễn Duy Tường Thi\n\nSpecial thanks to:\nAnh Mentor Trịnh Bảo Hưng\nCác thầy cô, anh chị trainers tại VNG\nVà quan trọng nhất là các bạn:người chơi"
	credit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	credit_label.add_theme_font_size_override("font_size", 32)
	$CinematicUI.add_child(credit_label)
	var screen_size = get_viewport_rect().size
	credit_label.size = Vector2(screen_size.x, 0)
	credit_label.position = Vector2(0, screen_size.y)
	
	var t = create_tween()
	var end_pos_y = -800.0
	t.tween_property(credit_label, "position:y", end_pos_y, 10.0)
	await t.finished
	get_tree().change_scene_to_file("res://scenes/game_screen/main_menu.tscn")
	
func get_active_foxy() -> AnimatedSprite2D:
	return foxy_sinner if foxy_sinner.visible else foxy_normal
	
func force_dialogic_on_top():
	for node in get_tree().root.get_children():
		if node is CanvasLayer and node.name.begins_with("Dialogic"):
			node.layer = 10
