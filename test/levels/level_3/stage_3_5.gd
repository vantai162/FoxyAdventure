extends StageBase
## ═══════════════════════════════════════════════════════════════════════════
## Level 3-5: THE HEART (Boss Arena) - HORIZONTAL ENTRY
## ═══════════════════════════════════════════════════════════════════════════
## Size: 1400 x 700 pixels (very wide, not tall!)
## Theme: Walk Into Your Fate → Triumph over Warlord Turtle
## Lighting: Dark purple cave (CanvasModulate 0.4, 0.35, 0.5)
##
## ═══════════════════════════════════════════════════════════════════════════
## DESIGN PHILOSOPHY - HORIZONTAL ENTRY
## ═══════════════════════════════════════════════════════════════════════════
##
## You don't DROP into a boss. You WALK toward your fate.
##
## LEFT (X: 0-400): Entry corridor
##   - Long tension-building approach
##   - Checkpoint before the gate
##   - Gate closes behind when you enter arena
##   - NO ESCAPE
##
## CENTER-RIGHT (X: 400-1400): Boss arena
##   - Wide floor for roll dodging
##   - Pillars for cover (ASYMMETRIC placement!)
##   - Water pit on RIGHT side (not center!)
##   - Boss at far right, facing player
##
## ═══════════════════════════════════════════════════════════════════════════
## WARLORD TURTLE BOSS MECHANICS:
## ═══════════════════════════════════════════════════════════════════════════
##
## - Dive Attack: Horizontal leap - JUMP to dodge
## - Coconut Throw: Arc trajectory - USE PILLARS for cover
## - Claw Swipe: Close range melee - BACK AWAY
## - Roll Attack: Full arena width - needs all that HORIZONTAL space!
##
## ═══════════════════════════════════════════════════════════════════════════
## ARENA ELEMENTS (ASYMMETRIC!):
## ═══════════════════════════════════════════════════════════════════════════
##
## PILLARS (3 total, NOT symmetric):
## - PillarFL: Front left (tall, narrow)
## - PillarM: Middle (shorter, wider)
## - PillarBR: Back right (angled placement)
## - BossRock: Rocky outcrop near boss
##
## WATER PIT (RIGHT side, not center!):
## - Creates "don't get pushed right" dynamic
## - Spikes at bottom
## - Bridge platforms over it
##
## HEAL POTIONS (risk/reward):
## - Behind front left pillar
## - Behind boss rock (dangerous!)
## ═══════════════════════════════════════════════════════════════════════════


func _init() -> void:
	# Level size: 1400 x 700 pixels (WIDE, not tall)
	camera_left = 0.0
	camera_right = 1400.0
	camera_top = 0.0
	camera_bottom = 700.0


func _ready() -> void:
	super._ready()
	_setup_gate_trigger()


func _setup_gate_trigger() -> void:
	var entry_gate = get_node_or_null("Puzzles/EntryGate")
	var gate_trigger = get_node_or_null("Puzzles/GateTrigger")
	
	if entry_gate:
		entry_gate.open_gate()  # Start open, player can walk in
		print("[Level 3-5] Entry gate open - walk toward your fate...")
	
	if gate_trigger:
		gate_trigger.body_entered.connect(_on_gate_trigger_entered)


func _on_gate_trigger_entered(body: Node2D) -> void:
	if body.name == "Foxy" or body.is_in_group("player"):
		lock_arena()


func _on_stage_ready() -> void:
	print("[Level 3-5] THE HEART - Boss Arena loaded")
	print("  Size: 1400 x 700 pixels (HORIZONTAL ENTRY!)")
	print("  Boss: WARLORD TURTLE (at far right)")
	print("  ")
	print("  ═══════════════════════════════════════════")
	print("  WARLORD TURTLE ATTACKS:")
	print("  ═══════════════════════════════════════════")
	print("  • Dive Attack - JUMP to dodge")
	print("  • Coconut Throw - USE PILLARS for cover")
	print("  • Claw Swipe - BACK AWAY")
	print("  • Roll Attack - Full arena width!")
	print("  ═══════════════════════════════════════════")
	print("  ")
	print("  Arena features (ASYMMETRIC!):")
	print("  - 3 pillars + rock for cover")
	print("  - Water pit on RIGHT (don't get pushed!)")
	print("  - Gate closes behind you - NO ESCAPE")


## Called when player enters arena (gate closes behind)
func lock_arena() -> void:
	var entry_gate = get_node_or_null("Puzzles/EntryGate")
	if entry_gate:
		entry_gate.close_gate()
		print("[Level 3-5] Arena locked! NO ESCAPE!")


## Called when boss is defeated (Level 3 complete!)
func unlock_victory() -> void:
	print("[Level 3-5] VICTORY! Warlord Turtle defeated!")
	print("[Level 3-5] Level 3 - The Sunken Depths COMPLETE!")
