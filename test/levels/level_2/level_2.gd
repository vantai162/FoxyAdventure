extends Node2D

@onready var settings_ui = preload("res://scenes/game_screen/settings_popup.tscn")
@onready var stage_music_id = "level_1_music"
@export var foxy_timeline_level2: String = "foxy_timeline_level2"
var foxy_timeline_level2_played = false
var cursetting=null
var can_pause = true

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
	AudioManager.play_music(stage_music_id,10.0,0.5)



func _process(delta: float) -> void:	
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


func _on_dialog_finished():
	var player = GameManager.player
	player.set_physics_process(true)
	can_pause = true

		


func _on_dialog_area_body_entered(body: Node2D) -> void:
	if not foxy_timeline_level2_played and body is Player:
		foxy_timeline_level2_played = true
		Dialogic.start(foxy_timeline_level2)
		await Dialogic.timeline_ended
		can_pause = true
		
