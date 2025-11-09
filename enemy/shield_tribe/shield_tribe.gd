extends EnemyCharacter
class_name ShieldTribe

@export_group("Combat")
@export var spear_damage: int = 1
@export var spear_active_duration: float = 0.4
@export var attack_interval: float = 2.0

@export_group("Defense")
@export var jump_react_range: float = 60.0
@export var jump_cooldown: float = 1.0
@export var sight_range: float = 85.0
@export var turn_delay: float = 0.35

@onready var shield: StaticBody2D = $Direction/Shield
@onready var attack_timer: Timer = $AttackTimer
@onready var spear_hit_area: Area2D = $Direction/SpearHitArea

var _is_turning: bool = false
var _pending_direction: int = 0

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

func _init_ray_cast() -> void:
	# Shield tribe is stationary and doesn't need raycasts used by moving enemies.
	# Override to avoid redundant initialization in the base class.
	return

func _on_hurt_area_2d_hurt(attack_direction: Vector2, damage: float) -> void:
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
		var desired: int = 1 if found_player.global_position.x > global_position.x else -1

		# If already facing desired direction nothing to do
		if desired == direction:
			return

		# If we're already turning, remember the latest desired direction and return
		if _is_turning:
			_pending_direction = desired
			return

		# Start a small delay before actually changing direction so player has
		# a window to hit the enemy's back.
		_is_turning = true
		_pending_direction = desired
		var t = get_tree().create_timer(turn_delay)
		t.timeout.connect(Callable(self, "_on_turn_timeout"))

func _on_turn_timeout() -> void:
	if _pending_direction != 0:
		change_direction(_pending_direction)
	_pending_direction = 0
	_is_turning = false

func perform_spear_attack():
	spear_hit_area.monitoring = true
	var timer = get_tree().create_timer(spear_active_duration)
	timer.connect("timeout", Callable(self, "_on_attack_finished"))

func _on_attack_finished():
	if is_instance_valid(spear_hit_area):
		spear_hit_area.monitoring = false
