extends Node2D

@onready var warlord = preload("res://enemy/boss/warlordturtle.tscn")
@onready var turtle_spawn = preload("res://spawner/turtle_spawner.tscn")
@onready var healpotion_spawn = preload("res://spawner/healthpotion_spawner.tscn")
@onready var settings_ui = preload("res://scenes/game_screen/settings_popup.tscn")
@export var timeline_name_1: String = "warlord_1"
@export var timeline_name_2: String = "warlord_2"
@onready var music_id = "warlord_theme"
var cursetting=null
var timeline2_triggered = false
var is_clean_up = false
var endgame = false
var warlord_spawned = false
var turtle_spawner_spawned = false
var healpotion_spawner_spawned = false
var boss_phase1_healthbar: TextureProgressBar
var boss_phase2_healthbar: TextureProgressBar
var boss
var can_pause = true
@onready var door = $DugeonGate
@onready var door_2 = $DugeonGate2
@onready var camera_target_boss =$CameraTarget

func _enter_tree() -> void:
	GameManager.current_stage = self

func _ready() -> void:
	AudioManager.stop_music()
	var editor_player = find_child("Foxy", true, false)
	if editor_player != null:
		if GameManager.player == null and GameManager.persistent_player_data.is_empty():
			GameManager.player = editor_player
		else:
			editor_player.queue_free()
	
	if GameManager.player == null:
		GameManager.request_player_spawn()
		
	
	
	if not GameManager.target_portal_name.is_empty():
		var portal = find_child(GameManager.target_portal_name)
		if portal != null and GameManager.player != null:
			GameManager.player.global_position = portal.global_position
		GameManager.target_portal_name = ""
	
	await GameManager.fade_from_black()






func _on_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _process(delta: float) -> void:
	if boss:
		if boss.current_phase == 2 and not endgame:
			boss_phase2_healthbar = $CanvasLayer/WarlordPhase2HealthBar
			boss_phase2_healthbar.setup()
			boss_phase2_healthbar.visible = true
			boss_phase1_healthbar.visible = false
		
		if boss.health <= 1 and not timeline2_triggered and not is_clean_up:
			timeline2_triggered = true
			is_clean_up = true
			if Dialogic.timeline_ended.is_connected(_on_dialog_finished):
				Dialogic.timeline_ended.disconnect(_on_dialog_finished)

			cleanup_after_winning()
			var player = GameManager.player
			player.set_physics_process(false)
			if player.has_method("stop_move"): 
				player.stop_move()
			player.position = Vector2(950,369)
			Dialogic.start(timeline_name_2)
			Dialogic.signal_event.connect(_on_dialogic_signal_event)
			Dialogic.timeline_ended.connect(_on_dialog_finished_2)
			AudioManager.stop_music(0.5)
			
			
	if Input.is_action_just_pressed("pause") and can_pause:
		if(GameManager.paused):
			hide_pop_up()
		else:
			create_and_open_setting_pop_up()

func create_and_open_setting_pop_up():
	if(cursetting==null):
		cursetting=settings_ui.instantiate()
		$CanvasLayer.add_child(cursetting)
		GameManager.pause_game()
	
func hide_pop_up():
	if(cursetting!=null):
		cursetting.hide_popup()
		cursetting.queue_free()	

func _on_meet_boss_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and warlord_spawned == false:
		warlord_spawned = true
		var cam = GameManager.player.get_node("Camera2D")
		AudioManager.play_sound("earthquake",10.0)
		await boss_entry_cinematic()
		# --- PAN CAMERA SANG CỬA ---
		boss = warlord.instantiate()
		boss.position = Vector2(1079, 369)
		add_child(boss)
		cam.global_position = camera_target_boss.global_position
		await get_tree().create_timer(0.5).timeout
		boss.set_physics_process(false)

		# --- HIỆN HỘI THOẠI ---
		Dialogic.start(timeline_name_1)
		AudioManager.play_music(music_id,10.0,0.5)
		Dialogic.timeline_ended.connect(_on_dialog_finished)
		
func boss_entry_cinematic():
	can_pause = false
	var player = GameManager.player
	var cam = player.get_node("Camera2D")
	
	player.set_physics_process(false)
	if player.has_method("stop_move"):
		player.stop_move()

	# ---- ĐÓNG CỬA + RUNG ----
	if door.has_method("close"):
		door.close()

	if cam.has_method("shake_tsunami"):
		cam.shake_tsunami(20.0, 1.0)

	await get_tree().create_timer(1.7).timeout



func _on_dialog_finished():
	var player = GameManager.player
	var cam = player.get_node("Camera2D")
	# --- CAMERA QUAY VỀ PLAYER ---
	cam.global_position = player.global_position
	await get_tree().create_timer(0.2).timeout
	player.set_physics_process(true)
	can_pause = true
	var spawner = turtle_spawn.instantiate()
	spawner.position = Vector2(676, 26)
	get_node("Spawner").add_child(spawner)
	turtle_spawner_spawned = true
		
	var heal_spawner = healpotion_spawn.instantiate()
	heal_spawner.position = Vector2(626,338)
	get_node("Spawner").add_child(heal_spawner)
	healpotion_spawner_spawned = true
		
	boss_phase1_healthbar = $CanvasLayer/WarlordHealthBar
	boss_phase1_healthbar.visible = true
	boss_phase1_healthbar.setup()
	
	if boss:
		boss.set_physics_process(true)
	
	
func _on_dialog_finished_2():
	var player = GameManager.player
	player.set_physics_process(true)
	can_pause = true

func cleanup_after_winning():
	# XÓA TẤT CẢ ENEMY TRONG MAP
	var enemies = get_node("Enemy")
	for e in enemies.get_children():
		e.queue_free()

	# XÓA TẤT CẢ SPAWNER
	var spawners = get_node("Spawner")
	for s in spawners.get_children():
		s.queue_free()
		
func _on_dialogic_signal_event(argument: String):
	var player = GameManager.player
	endgame = true
	boss_phase2_healthbar.visible = false
	# --- GỌI HÀM RESET NƯỚC CÓ SẴN CỦA BẠN ---
		# 1. Tìm node nước (Thay "WaterArea" bằng tên thật của node nước trong Scene của bạn)
	var water_node = find_child("water", true, false) 
		
		# 2. Reset water to normal level
	if water_node:
		if water_node.has_method("return_to_normal"):
			water_node.return_to_normal(2.0)
			print("Đã cho nước rúttt")
		else:
			print("Lỗi: Tìm thấy node nước nhưng không thấy hàm return_to_normal!")
			
	if argument == "kill_warlord":
		boss.die()
	if argument == "spare_warlord":
		boss.queue_free()
	door_2.close()
