extends EnemyCharacter
class_name EliteSniperSeahorse
## Elite Seahorse: "The Sniper"
## Stationary turret with diagonal tracking
## Fires 5-shot burst (vs base 3), faster timing, player tracking with lerp

@export var bullet_speed: float = 300
@onready var bullet_factory := $Direction/BulletFactory

func _ready() -> void:
	# NOTE: Scene must have States/SniperShoot node
	fsm = FSM.new(self, $States, $States/Idle)
	change_direction(-1)
	super._ready()

func fire() -> void:
	var bullet := bullet_factory.create() as RigidBody2D
	var shooting_velocity := Vector2(bullet_speed * direction, 0.0)
	bullet.apply_impulse(shooting_velocity)

# Player detection triggers sniper mode
func _on_player_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		found_player = body
		if fsm.current_state == fsm.states.idle:
			if fsm.states.has("sniper_shoot"):
				fsm.change_state(fsm.states.snipershoot)

func _on_player_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		found_player = null
		# Sniper state will handle returning to idle when burst complete

func _on_hurt_area_2d_hurt(direction: Vector2, damage: float) -> void:
	# Turn to face attacker if hit from behind
	if direction.x != 0:
		var attacker_side = -sign(direction.x)
		if attacker_side != self.direction:
			change_direction(attacker_side)
	
	take_damage(damage)
	fsm.change_state(fsm.states.hurt)
