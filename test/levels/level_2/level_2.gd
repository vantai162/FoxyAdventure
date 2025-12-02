extends Node2D

@onready var warlord = preload("res://enemy/boss/warlordturtle.tscn")
@onready var turtle_spawn = preload("res://spawner/turtle_spawner.tscn")
@onready var healpotion_spawn = preload("res://spawner/healthpotion_spawner.tscn")
@onready var settings_ui = preload("res://scenes/game_screen/settings_popup.tscn")
@export var timeline_name_1: String = "warlord_1"
@export var timeline_name_2: String = "warlord_2"
var timeline2_triggered = false
var is_clean_up = false
var endgame = false
@onready var theme = $WarlordTheme
var warlord_spawned = false
var turtle_spawner_spawned = false
var healpotion_spawner_spawned = false
var boss_phase1_healthbar: TextureProgressBar
var boss_phase2_healthbar: TextureProgressBar
var boss


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
			cleanup_after_winning()
			var player = GameManager.player
			player.set_physics_process(false)
			if player.has_method("stop_move"): 
				player.stop_move()
			player.position = Vector2(608,465)
			Dialogic.start(timeline_name_2)
			Dialogic.signal_event.connect(_on_dialogic_signal_event)
			Dialogic.timeline_ended.connect(_on_dialog_finished)
			theme.stop()
			
			
	if Input.is_action_just_pressed("pause"):
		if GameManager.paused:
			return
		var settings = settings_ui.instantiate()
		$CanvasLayer.add_child(settings)


func _on_meet_boss_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and warlord_spawned == false:
		boss = warlord.instantiate()
		boss.position = Vector2(468, 400)
		add_child(boss)
		warlord_spawned = true
		
		var spawner = turtle_spawn.instantiate()
		spawner.position = Vector2(839, 36)
		get_node("Spawner").add_child(spawner)
		turtle_spawner_spawned = true
		
		var heal_spawner = healpotion_spawn.instantiate()
		heal_spawner.position = Vector2(1077,452)
		get_node("Spawner").add_child(heal_spawner)
		healpotion_spawner_spawned = true
		
		boss_phase1_healthbar = $CanvasLayer/WarlordHealthBar
		boss_phase1_healthbar.visible = true
		boss_phase1_healthbar.setup()
		
		#dialog
		var player = GameManager.player
		player.set_physics_process(false)
		if player.has_method("stop_move"): 
			player.stop_move()
		Dialogic.start(timeline_name_1)
		Dialogic.timeline_ended.connect(_on_dialog_finished)
		theme.play()

func _on_dialog_finished():
	var player = GameManager.player
	player.set_physics_process(true)
	
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
	if argument == "kill_warlord":
		boss.die()
	if argument == "spare_warlord":
		boss.queue_free()
