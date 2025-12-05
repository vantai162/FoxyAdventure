extends StageBase
## Level 3-3: THE ASCENT
## Size: 1400 x 1600 pixels
## 
## ═══════════════════════════════════════════════════════════════════════════
## THE JOURNEY - CLIMBING UP (reversal of expectations!)
## ═══════════════════════════════════════════════════════════════════════════
##
## Player enters at BOTTOM, exits at TOP. After descending through 3-1 and
## navigating sideways through 3-2, this is the REVERSAL. Rising up through
## ancient ruins feels like progress, like fighting against gravity.
##
## TWO CLIMBING ROUTES (not symmetric!):
##
## LEFT PATH - Water Ruins
##   - Flooded sections, platforms among ruins
##   - Glowing mushrooms light the way
##   - Easier but longer route
##   - Atmospheric, exploratory feel
##
## RIGHT PATH - Shield Tribe Territory  
##   - THE SKILL GATE of Level 3
##   - Shield Tribe blocks front, 0.35s turn delay
##   - Player must position behind to attack
##   - Harder but shorter route
##
## Both routes converge at TOP where lever opens exit gate.
##
## TEACHING: Shield Tribe - blocks front, turn delay exploitable
## Player applies positioning skills learned from aggressive tribe dodging
## ═══════════════════════════════════════════════════════════════════════════


func _init() -> void:
	camera_left = 0.0
	camera_right = 1400.0
	camera_top = 0.0
	camera_bottom = 1600.0


func _ready() -> void:
	super._ready()
	_connect_lever_to_gate()


func _connect_lever_to_gate() -> void:
	var lever = get_node_or_null("Puzzles/ExitLever")
	var gate = get_node_or_null("Puzzles/ExitGate")
	if lever and gate:
		lever.lever_activated.connect(gate.open_gate)
		lever.lever_deactivated.connect(gate.close_gate)


func _on_stage_ready() -> void:
	print("[Level 3-3] The Ascent loaded")
	print("  Size: 1400 x 1600 pixels (CLIMBING UP!)")
	print("  ROUTES: Left (water, easier) / Right (shield tribe, skill gate)")
	print("  TEACHING: Shield Tribe - must attack from behind")
