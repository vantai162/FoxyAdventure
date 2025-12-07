extends EnemyCharacter


@export var bullet_speed: float = 300
@onready var bullet_factory := $Direction/BulletFactory

func _ready() -> void:

	fsm = FSM.new(self, $States, $States/Idle)
	change_direction(-1)
	super._ready()

func fire() -> void:

	var bullet := bullet_factory.create() as RigidBody2D

	var shooting_velocity := Vector2(bullet_speed * direction, 0.0)

	bullet.apply_impulse(shooting_velocity)

func _on_hurt_area_2d_hurt(direction: Vector2, damage: float) -> void:
	# Turn to face attacker if hit from behind (immediately, before knockback)
	# Direction points FROM attacker TO us, so negate to get attacker's position
	if direction.x != 0:
		var attacker_side = -sign(direction.x)
		if attacker_side != self.direction:
			change_direction(attacker_side)
	
	take_damage(damage)
	fsm.change_state(fsm.states.hurt)
