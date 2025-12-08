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

@onready var lever: Lever = $Puzzle/TreasureLever
@onready var gate: Gate = $Puzzle/TreasureGate


func _init() -> void:
	# Camera bounds for this level
	camera_left = 0.0
	camera_right = 1600.0
	camera_top = 0.0
	camera_bottom = 2400.0


func _ready() -> void:
	super._ready()
	# Connect lever to gate
	if lever and gate:
		lever.lever_activated.connect(_on_lever_activated)
		lever.lever_deactivated.connect(_on_lever_deactivated)


func _on_lever_activated() -> void:
	if gate:
		gate.open_gate()


func _on_lever_deactivated() -> void:
	if gate:
		gate.close_gate()


func _on_stage_ready() -> void:
	pass  # Stage loaded
