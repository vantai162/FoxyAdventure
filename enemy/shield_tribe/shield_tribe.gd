extends EnemyCharacter
class_name ShieldTribe

@onready var shield: StaticBody2D = $Direction/Shield
@onready var attack_timer: Timer = $AttackTimer
@onready var spear_hit_area: Area2D = $Direction/SpearHitArea

func _ready() -> void:
	fsm = FSM.new(self, $States, $States/idle)
	super._ready()
	_init_ray_cast()
	_init_detect_player_area()
	_init_hurt_area()
	
	spear_hit_area.monitoring = false

func _init_hurt_area():
	if has_node("Direction/HurtArea2D"):
		var hurt_area = $Direction/HurtArea2D
		hurt_area.hurt.connect(_on_hurt_area_2d_hurt)

func _on_hurt_area_2d_hurt(attack_direction: Vector2, damage: int) -> void:
	if fsm.current_state.name == "defend" or fsm.current_state.name == "attack":
		var attack_side = sign(attack_direction.x)
		if attack_side == 0:
			attack_side = 1
		
		if attack_side == direction:
			return
	
	take_damage(damage)
	if health > 0:
		fsm.change_state(fsm.states.hurt)

func _on_player_in_sight(_player_pos: Vector2) -> void:
	if fsm.current_state.name != "defend" and fsm.current_state.name != "attack":
		fsm.change_state(fsm.states.defend)

func _on_player_not_in_sight() -> void:
	if fsm.current_state.name == "defend" or fsm.current_state.name == "attack":
		fsm.change_state(fsm.states.idle)

func face_player() -> void:
	if found_player:
		if found_player.global_position.x > global_position.x:
			change_direction(1)
		else:
			change_direction(-1)

func perform_spear_attack():
	spear_hit_area.monitoring = true
	var timer = get_tree().create_timer(0.4)
	timer.connect("timeout", Callable(self, "_on_attack_finished"))

func _on_attack_finished():
	if is_instance_valid(spear_hit_area):
		spear_hit_area.monitoring = false
