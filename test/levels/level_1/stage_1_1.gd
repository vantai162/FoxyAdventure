extends StageBase
## Level 1: Tutorial Island - The Awakening
## Size: ~7000x1000 pixels (horizontal scrolling)
## 
## EXPERIENCE DESIGN:
## This is the opening level where Fox wakes up on the beach. It introduces
## basic movement, combat, and story through the wake-up cinematic and dialogue.
##
## SPECIAL FEATURES:
## - Wake-up cinematic on first play
## - Dialogic timeline integration
## - Music starts after intro


@onready var wake_up_cinematic_scn = preload("res://cut_scene/wakeup_cutscene/wake_up_cutscene.tscn")

## Music track ID from AudioDatabase
@export var music_id: String = "level_1_music"

## Dialogic timeline for wake-up sequence
@export var wakeup_timeline: String = "wake_up_timeline"

## Tracks whether wake-up has played (prevents replay on respawn)
var wake_up_scn_played: bool = false



func _init() -> void:
	# Camera bounds for Level 1 (horizontal scroller)
	# X: 0 to ~7000, Y: -400 to 600
	camera_left = -100.0
	camera_right = 7200.0
	camera_top = -400.0
	camera_bottom = 500.0


func _on_stage_ready() -> void:
	# Play intro cinematic on first entry
	if GameManager.player and not wake_up_scn_played:
		await _play_intro_cinematic()
	else:
		# If returning (e.g., from checkpoint), just start music
		can_pause = true
		AudioManager.play_music(music_id, 8.0, 0.5)


func _on_stage_process(_delta: float) -> void:
	# Pause menu is handled by StageBase, but we gate it with can_pause
	# Override pause handling during cinematics
	if Input.is_action_just_pressed("pause") and not can_pause:
		# Block pause during cinematic - do nothing
		return


func _play_intro_cinematic() -> void:
	# Disable pause during cinematic
	can_pause = false
	
	# 1. Create and play the wake-up cinematic
	var cinematic = wake_up_cinematic_scn.instantiate()
	add_child(cinematic)
	GameManager.player.input_locked = true
	# 2. Wait for cinematic to finish
	await cinematic.finished
	wake_up_scn_played = true
	cinematic.queue_free()
	GameManager.player.input_locked = false
	# 3. Start dialogue
	print("[Level1] Intro complete, starting dialogue")
	Dialogic.start(wakeup_timeline)
	await Dialogic.timeline_ended
	
	# 4. Enable pause and start music
	can_pause = true
	AudioManager.play_music(music_id, 8.0, 0.5)
