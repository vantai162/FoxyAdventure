extends EnemyCharacter
class_name EliteSniperSeahorse
## Elite Barrel: "The Sniper"
## Stationary turret with diagonal tracking
## Fires 5-shot burst (vs base 3), faster timing, player tracking with lerp

@export var bullet_speed: float = 300
@onready var bullet_factory := $Direction/BulletFactory

func _ready() -> void:
	# NOTE: Scene must have States/SniperShoot node
	fsm = FSM.new(self, $States, $States/Idle)
	change_direction(-1)
	super._ready()

# Player detection triggers sniper mode
func _on_player_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		found_player = body
		if fsm and fsm.current_state and fsm.current_state == fsm.states.idle:
			if fsm.states.has("snipershoot"):  # Elite has sniper state
				fsm.change_state(fsm.states.snipershoot)

func _on_player_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		found_player = null
		# Sniper state will handle returning to idle when burst complete
