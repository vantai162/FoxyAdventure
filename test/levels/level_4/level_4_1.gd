extends StageBase


@export var timeline_name_1: String = "foxy_timeline_4_1"

## Boss state tracking
var boss: Node = null
var king_crab_spawned = false
signal player_entered
## UI references
var boss_phase1_healthbar: TextureProgressBar
var boss_phase2_healthbar: TextureProgressBar

## Phase/ending tracking
var endgame: bool = false

func _on_stage_ready() -> void:
	# Stop any previous music - boss arena is silent until fight
	AudioManager.stop_music()
	AudioManager.switch_sfx_bus("SFX")

func _ready():
	# Gọi hàm cha để StageBase vẫn chạy logic của nó
	super._ready()
	boss = $KingCrab
	

func _on_stage_process(_delta: float) -> void:
	if boss:
		_update_boss_state()



func _update_boss_state() -> void:
	# Handle phase 2 transition
	if boss.current_phase == 2 and not endgame:
		boss_phase2_healthbar = $CanvasLayer/KingPhase2HealthBar
		boss_phase2_healthbar.setup()
		boss_phase2_healthbar.visible = true
		boss_phase1_healthbar.visible = false
	


func _on_king_crab_trigger_body_entered(body: Node2D) -> void:
	if body is Player and not king_crab_spawned:
		var player = GameManager.player
		can_pause = false
		player.set_physics_process(false)
		king_crab_spawned = true
		Dialogic.start(timeline_name_1)
		Dialogic.timeline_ended.connect(_on_dialog_finished)
		
		
func _on_dialog_finished() -> void:
	# Khi timeline kết thúc thì mới phát signal
	emit_signal("player_entered")
	boss_phase1_healthbar = $CanvasLayer/KingHealthBar
	boss_phase1_healthbar.visible = true
	boss_phase1_healthbar.setup()
