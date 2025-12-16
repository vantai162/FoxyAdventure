extends StageBase
## Level 2: The Journey Continues
## Size: ~6000x1400 pixels (mixed horizontal/vertical)
## 
## EXPERIENCE DESIGN:
## Continuation of the adventure after the beach. Introduces more complex
## platforming and enemies. Leads to the boss arena (level_2.2).
##
## SPECIAL FEATURES:
## - Standard level with music
## - Dialog system integration


## Music track ID from AudioDatabase
@export var stage_music_id: String = "level_1_music"


func _init() -> void:
	# Camera bounds for Level 2
	# X: -600 to 5600, Y: -700 to 600
	camera_left = -600.0
	camera_right = 5600.0
	camera_top = -700.0
	camera_bottom = 600.0


func _on_stage_ready() -> void:
	# Start music when stage is ready
	AudioManager.play_music(stage_music_id, 10.0, 0.5)


func _on_dialog_finished() -> void:
	# Called when any Dialogic timeline ends in this level
	var player = GameManager.player
	if player:
		player.set_physics_process(true)
