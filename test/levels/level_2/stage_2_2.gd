extends StageBase
## Level 2.2: Warlord Turtle Boss Arena
## Size: ~4000x900 pixels (arena layout)
## 
## EXPERIENCE DESIGN:
## The climactic boss fight of the early game. Warlord Turtle attacks with
## multiple phases, rising water, and spawning minions.
##
## SPECIAL FEATURES:
## - Boss entry cinematic with camera shake
## - Multi-phase boss fight
## - Dynamic spawners (turtles, health potions)
## - Water level mechanics
## - Door closing on entry (no escape)
## - Dialogic integration for pre/post battle dialogue


@onready var warlord_scene = preload("res://enemy/boss/warlordturtle.tscn")
@onready var turtle_spawn_scene = preload("res://spawner/turtle_spawner.tscn")
@onready var healpotion_spawn_scene = preload("res://spawner/healthpotion_spawner.tscn")

## Dialogic timeline names
@export var timeline_name_1: String = "warlord_1"
@export var timeline_name_2: String = "warlord_2"

## Boss music
@export var music_id: String = "warlord_theme"

## Boss state tracking
var boss: Node = null
var warlord_spawned: bool = false
var turtle_spawner_spawned: bool = false
var healpotion_spawner_spawned: bool = false

## Phase/ending tracking
var timeline2_triggered: bool = false
var is_clean_up: bool = false
var endgame: bool = false

## UI references
var boss_phase1_healthbar: TextureProgressBar
var boss_phase2_healthbar: TextureProgressBar


## Node references (set by @onready after scene loads)
@onready var door = $DugeonGate
@onready var door_2 = $DugeonGate2
@onready var camera_target_boss = $CameraTarget


func _init() -> void:
	# Camera bounds for Boss Arena
	# X: -1200 to 3000, Y: -400 to 600
	camera_left = -1200.0
	camera_right = 3000.0
	camera_top = -400.0
	camera_bottom = 600.0


func _on_stage_ready() -> void:
	# Stop any previous music - boss arena is silent until fight
	AudioManager.stop_music()


func _on_stage_process(_delta: float) -> void:
	if boss:
		_update_boss_state()



func _update_boss_state() -> void:
	# Handle phase 2 transition
	if boss.current_phase == 2 and not endgame:
		boss_phase2_healthbar = $CanvasLayer/WarlordPhase2HealthBar
		boss_phase2_healthbar.setup()
		boss_phase2_healthbar.visible = true
		boss_phase1_healthbar.visible = false
	
	# Handle boss defeat
	if boss.health <= 1 and not timeline2_triggered and not is_clean_up:
		timeline2_triggered = true
		is_clean_up = true
		
		# Disconnect old signal if connected
		if Dialogic.timeline_ended.is_connected(_on_dialog_finished):
			Dialogic.timeline_ended.disconnect(_on_dialog_finished)
		
		_trigger_victory_sequence()


func _trigger_victory_sequence() -> void:
	# Clean up arena
	_cleanup_after_winning()
	
	# Freeze player for dialogue
	var player = GameManager.player
	player.set_physics_process(false)
	if player.has_method("stop_move"):
		player.stop_move()
	player.position = Vector2(950, 369)
	
	# Start victory dialogue
	Dialogic.start(timeline_name_2)
	can_pause = false
	Dialogic.signal_event.connect(_on_dialogic_signal_event)
	Dialogic.timeline_ended.connect(_on_dialog_finished_2)
	AudioManager.stop_music(0.5)


## Called by MeetBossArea2D when player enters
func _on_meet_boss_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not warlord_spawned:
		warlord_spawned = true
		
		var cam = GameManager.player.get_node("Camera2D")
		AudioManager.play_sound("earthquake", 10.0)
		
		await _boss_entry_cinematic()
		
		# Spawn the boss
		boss = warlord_scene.instantiate()
		boss.position = Vector2(1079, 369)
		add_child(boss)
		
		# Pan camera to boss
		cam.global_position = camera_target_boss.global_position
		await get_tree().create_timer(0.5).timeout
		boss.set_physics_process(false)
		
		# Start pre-battle dialogue
		Dialogic.start(timeline_name_1)
		AudioManager.play_music(music_id, 10.0, 0.5)
		Dialogic.timeline_ended.connect(_on_dialog_finished)


func _boss_entry_cinematic() -> void:
	can_pause = false
	
	var player = GameManager.player
	var cam = player.get_node("Camera2D")
	
	# Freeze player
	player.set_physics_process(false)
	if player.has_method("stop_move"):
		player.stop_move()
	
	# Close the door - no escape!
	if door.has_method("close"):
		door.close()
	
	# Camera shake for dramatic effect
	if cam.has_method("shake_tsunami"):
		cam.shake_tsunami(20.0, 1.0)
	
	await get_tree().create_timer(1.7).timeout


func _on_dialog_finished() -> void:
	var player = GameManager.player
	var cam = player.get_node("Camera2D")
	
	# Return camera to player
	cam.global_position = player.global_position
	await get_tree().create_timer(0.2).timeout
	
	# Unfreeze player
	player.set_physics_process(true)
	can_pause = true
	
	# Spawn support elements
	var spawner = turtle_spawn_scene.instantiate()
	spawner.position = Vector2(676, 26)
	get_node("Spawner").add_child(spawner)
	turtle_spawner_spawned = true
	
	var heal_spawner = healpotion_spawn_scene.instantiate()
	heal_spawner.position = Vector2(626, 338)
	get_node("Spawner").add_child(heal_spawner)
	healpotion_spawner_spawned = true
	
	# Setup boss health bar
	boss_phase1_healthbar = $CanvasLayer/WarlordHealthBar
	boss_phase1_healthbar.visible = true
	boss_phase1_healthbar.setup()
	
	# Activate boss
	if boss:
		boss.set_physics_process(true)


func _on_dialog_finished_2() -> void:
	var player = GameManager.player
	player.set_physics_process(true)
	can_pause = true


func _cleanup_after_winning() -> void:
	# Clear all enemies
	var enemies = get_node_or_null("Enemy")
	if enemies:
		for e in enemies.get_children():
			e.queue_free()
	
	# Clear all spawners
	var spawners = get_node_or_null("Spawner")
	if spawners:
		for s in spawners.get_children():
			s.queue_free()


func _on_dialogic_signal_event(argument: String) -> void:
	endgame = true
	boss_phase2_healthbar.visible = false
	
	# Handle water reset
	var water_node = find_child("water", true, false)
	if water_node and water_node.has_method("return_to_normal"):
		water_node.return_to_normal(2.0)
		print("[BossArena] Water receding...")
	
	# Handle boss fate based on player choice
	if argument == "kill_warlord":
		boss.die()
	elif argument == "spare_warlord":
		_spare_warlord_escape()
	
	# Close exit door (for now)
	door_2.close()
	
	
func _spare_warlord_escape() -> void:
	if not boss:
		return
	boss.change_animation("idle")
	# Disable boss AI/physics
	boss.set_physics_process(false)
	await get_tree().create_timer(2.0).timeout
	var cam = GameManager.player.get_node("Camera2D")
	AudioManager.play_sound("earthquake")
	cam.shake_tsunami()
	AudioManager.play_sound("")
	var target_pos = boss.position + Vector2(0, -600) 
	var tween = create_tween()
	tween.tween_property(boss, "position", target_pos,2.0  # thời gian dài hơn để thấy rõ giảm tốc
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)  # Ease-out: chậm dần khi 
	tween.finished.connect(func():
		boss.queue_free()
	)
