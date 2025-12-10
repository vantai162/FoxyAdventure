extends EnemyCharacter
## Elite Barrel: "The Sniper"
## Stationary turret with diagonal tracking
## Fires 5-shot burst (vs base 3), faster timing, player tracking with lerp

@export var bullet_speed: float = 300
@onready var bullet_factory := $Direction/BulletFactory

func _ready() -> void:
	# NOTE: Scene must have States/Shoot node (elite sniper variant)
	fsm = FSM.new(self, $States, $States/Idle)
	super._ready()
	# Direction is set by editor via @export var direction in BaseCharacter
	# Bullet factory will respect current direction when firing

# Override base detection to trigger sniper mode
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		found_player = body
		if fsm and fsm.current_state and fsm.current_state == fsm.states.idle:
			fsm.change_state(fsm.states.shoot)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		found_player = null
		# Sniper shoot state checks found_player and aborts burst if player escapes
