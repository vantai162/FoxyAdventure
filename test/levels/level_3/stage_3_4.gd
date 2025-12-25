extends StageBase
## Level 3-4: THE WINDING GAUNTLET
## Size: 1600 x 1200 pixels
## 
## ═══════════════════════════════════════════════════════════════════════════
## DESIGN PHILOSOPHY - NOT A VERTICAL SLIDE!
## ═══════════════════════════════════════════════════════════════════════════
##
## Path WINDS back and forth horizontally:
##
## START (left, Y~300) → RIGHT through spike corridor (timing test)
##                     ↓ drop into crossfire chamber
##                     ← LEFT back (under start!) through wind tunnel
##                     ↓ drop into final stretch
##                     → RIGHT to exit climb
##
## You double back HORIZONTALLY, see areas before reaching them.
## Chambers alternate with tight corridors.
##
## ═══════════════════════════════════════════════════════════════════════════
## SECTION BREAKDOWN:
## ═══════════════════════════════════════════════════════════════════════════
##
## 1. SPIKE CORRIDOR (going RIGHT, X: 140→1100)
##    - Retractable spikes, low ceiling
##    - Can't jump over, must time your run
##
## 2. CROSSFIRE CHAMBER (wide room, Y~500-720)
##    - Seahorses on elevated ledges shoot crossfire
##    - Cover blocks (irregular heights)
##    - Mushroom punishes camping
##
## 3. WIND TUNNEL (going LEFT, X: 600→200)
##    - Wind pushes toward left wall spikes
##    - Aggressive tribe throws coconuts
##    - Fight wind AND dodge projectiles
##
## 4. FINAL STRETCH (going RIGHT, X: 700→1500)
##    - Stalactites falling
##    - Multiple enemies
##    - Exit climb at far right
## ═══════════════════════════════════════════════════════════════════════════


func _init() -> void:

	camera_left = 0.0
	camera_right = 1600.0
	camera_top = 0.0
	camera_bottom = 1200.0


func _on_stage_ready() -> void:
	AudioManager.switch_sfx_bus("SFX_Cave")
	print("[Level 3-4] The Winding Gauntlet loaded")
	print("  Size: 1600 x 1200 pixels")
	print("  PATH: RIGHT → DROP → LEFT → DROP → RIGHT (zigzag!)")
	print("  TESTS: Timing, crossfire, wind+projectiles, precision")
	print("  NEXT: Boss Fight (3-5)")
	#GameManager.skin_manager.cur_skin_data["SinnerFoxy"].UnlockToBuy()
	#GameManager.skin_manager._save_skin_data()
