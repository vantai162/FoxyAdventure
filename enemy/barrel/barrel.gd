extends EnemyCharacter


@export var bullet_speed: float = 300
@onready var bullet_factory := $Direction/BulletFactory

func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Idle)
	super._ready()
	# Direction is set by editor via @export var direction in BaseCharacter
	# Bullet factory will respect current direction when firing
