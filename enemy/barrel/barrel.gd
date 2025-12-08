extends EnemyCharacter


@export var bullet_speed: float = 300
@onready var bullet_factory := $Direction/BulletFactory

func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Idle)
	change_direction(-1)
	super._ready()

