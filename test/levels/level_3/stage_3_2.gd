extends StageBase
## Level 3-2: THE LABYRINTH
## Size: 2000 x 1200 pixels (WIDER than TALL - horizontal exploration!)
## 
## ═══════════════════════════════════════════════════════════════════════════
## THE JOURNEY - Sideways Navigation
## ═══════════════════════════════════════════════════════════════════════════
##
## This is the first level that's WIDER than TALL. Player explores sideways,
## not just dropping down. Multiple paths, junctions, choices.
##
## SHAPE (top-down path view):
##
##   SPAWN                              water grotto
##     │                                     │
##     ▼                                     ▼
##   entry ─────► upper passage ─────► flooded chamber
##     │              │                      │
##     │              │                      │
##     ▼              ▼                      ▼
##   lower ◄──── junction ◄──────────── bridge
##   path             │
##     │              │
##     └──────► tribe camp ──────────────► EXIT
##
## TEACHING:
## - Seahorse: Player sees from above (safe), then must cross water
## - Aggressive Tribe: Demo on platform, then real combat on ground
##
## FEELING: Exploration, navigation, "where does this lead?"
##
## CONNECTION: JunctionLever and CampGate use Channel System
## Set in scene: JunctionLever.channel = "junction", CampGate.listen_channel = "junction"
## ═══════════════════════════════════════════════════════════════════════════


func _init() -> void:
	camera_left = 0.0
	camera_right = 2000.0
	camera_top = 0.0
	camera_bottom = 1200.0


func _ready() -> void:
	super._ready()
	AudioManager.switch_sfx_bus("SFX_Cave")
	AudioManager.play_music("ambience_cave",5.0)
	# Lever/Gate connection now handled by Channel System in inspector


func _on_stage_ready() -> void:
	print("[Level 3-2] The Labyrinth loaded")
	print("  Size: 2000 x 1200 pixels (HORIZONTAL)")
	print("  TEACHING: Seahorse in grotto, Aggressive Tribe at camp")
	print("  PATHS: Upper (grotto) / Lower (crabs) → Junction → Camp → Exit")
