extends StageBase
## Level 3-1: The Twilight Descent
## Size: 1600x2400 pixels (50x75 tiles @ 32px)
## 
## EXPERIENCE DESIGN:
## This level teaches caves are different. It introduces mushrooms, turtles,
## water swimming, and the lever/gate puzzle mechanic.
##
## THE HOOK: Player immediately sees a locked gate with gold chest behind it.
## They must descend, find the lever (past a commitment drop), then can
## return via platforms to claim the reward.
##
## EMOTIONAL ARC: SAFETY → CURIOSITY → COMMITMENT → TENSION → RELIEF
##
## CONNECTION: TreasureLever and TreasureGate use Channel System
## Set in scene: TreasureLever.channel = "treasure", TreasureGate.listen_channel = "treasure"


func _init() -> void:
	# Camera bounds for this level
	camera_left = 0.0
	camera_right = 1600.0
	camera_top = 0.0
	camera_bottom = 2400.0


func _ready() -> void:
	super._ready()
	AudioManager.switch_sfx_bus("SFX_Cave")
	AudioManager.play_music("ambience_cave",5.0)
	# Lever/Gate connection now handled by Channel System in inspector


func _on_stage_ready() -> void:
	pass  # Stage loaded
