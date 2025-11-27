extends Node2D

@onready var warlord = preload("res://enemy/boss/warlordturtle.tscn")
@onready var turtle_spawn = preload("res://spawner/turtle_spawner.tscn")
@onready var healpotion_spawn = preload("res://spawner/healthpotion_spawner.tscn")
@onready var wake_up_cinematic_scn = preload("res://cut_scene/wake_up_cutscene.tscn")
@onready var bgm = $AudioStreamPlayer
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
		if boss.current_phase == 2:
			boss_phase2_healthbar = $CanvasLayer/WarlordPhase2HealthBar
			boss_phase2_healthbar.setup()
			boss_phase2_healthbar.visible = true
			boss_phase1_healthbar.visible = false

func _on_meet_boss_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and warlord_spawned == false:
		boss = warlord.instantiate()
		boss.position = Vector2(468, 400)
		add_child(boss)
		warlord_spawned = true
		
		var spawner = turtle_spawn.instantiate()
		spawner.position = Vector2(839, 36)
		add_child(spawner)
		turtle_spawner_spawned = true
		
		var heal_spawner = healpotion_spawn.instantiate()
		heal_spawner.position = Vector2(1077,452)
		add_child(heal_spawner)
		healpotion_spawner_spawned = true
		
		boss_phase1_healthbar = $CanvasLayer/WarlordHealthBar
		boss_phase1_healthbar.visible = true
		boss_phase1_healthbar.setup()
		
