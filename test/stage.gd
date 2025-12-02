extends Node2D


@onready var wake_up_cinematic_scn = preload("res://cut_scene/wake_up_cutscene.tscn")
@onready var bgm = $AudioStreamPlayer
@onready var settings_ui = preload("res://scenes/game_screen/settings_popup.tscn")
@export var wakeup_timeline: String = "wake_up_timeline"

func _enter_tree() -> void:
	GameManager.current_stage = self

func _ready() -> void:
	var editor_player = find_child("Foxy", true, false)
	if editor_player != null:
		if GameManager.player == null and GameManager.persistent_player_data.is_empty():
			GameManager.player = editor_player
		else:
			editor_player.queue_free()
	
	if GameManager.player == null:
		GameManager.request_player_spawn()
		
	# --- BẮT ĐẦU CINEMATIC ---
	if GameManager.player:
		play_intro_cinematic()
	
	
	if not GameManager.target_portal_name.is_empty():
		var portal = find_child(GameManager.target_portal_name)
		if portal != null and GameManager.player != null:
			GameManager.player.global_position = portal.global_position
		GameManager.target_portal_name = ""
	
	await GameManager.fade_from_black()


func _process(delta: float) -> void:
	if(Input.is_action_just_pressed("pause")):
		if(GameManager.paused):
			GameManager.unpause()
		else:
			GameManager.pause_game()

func _on_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		if GameManager.paused:
			return
		var settings = settings_ui.instantiate()
		$CanvasLayer.add_child(settings)
			

func play_intro_cinematic():
	# 1. Tạo instance của Cinematic
	var cinematic = wake_up_cinematic_scn.instantiate()
	
	# 2. Thêm vào cây scene
	add_child(cinematic)
	
	# 3. Chờ tín hiệu "finished" từ nó
	await cinematic.finished
	
	# 4. SAU KHI CINEMATIC XONG THÌ LÀM GÌ?
	print("Intro xong, bắt đầu game!")
	Dialogic.start(wakeup_timeline) # Hiện hội thoại tự hỏi
	if bgm: 
		bgm.volume_db = -20 # Mẹo: Set nhỏ trước
		bgm.play()
		create_tween().tween_property(bgm, "volume_db", 0.0, 2.0)


		
