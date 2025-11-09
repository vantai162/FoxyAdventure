extends EnemyCharacter
class_name ShieldTribe

@export_group("Combat")
@export var spear_damage: int = 1
@export var spear_active_duration: float = 0.4
@export var attack_interval: float = 2.0
@export var attack_animation_duration: float = 0.8

@export_group("Defense")
@export var jump_react_range: float = 60.0
@export var jump_cooldown: float = 1.0
@export var sight_range: float = 85.0
@export var turn_delay: float = 0.35

@onready var shield: StaticBody2D = $Direction/Shield
@onready var spear: Node2D = $Direction/Spear
@onready var spear_sprite: AnimatedSprite2D = $Direction/Spear/AnimatedSprite2D
@onready var spear_hit_area: Area2D = $Direction/Spear/SpearHitArea
@onready var attack_timer: Timer = $AttackTimer

var _is_turning: bool = false
var _pending_direction: int = 0

func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Idle)
	super._ready()
	
	# Start with both shield and spear hidden
	shield.hide()
	shield.get_node("CollisionShape2D").disabled = true
	spear.hide()
	spear_hit_area.monitoring = false

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
		attack_timer.stop()
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
	spear.show()
	spear_sprite.play("attack")
	spear_hit_area.monitoring = true
	var timer = get_tree().create_timer(spear_active_duration)
	timer.connect("timeout", Callable(self, "_on_attack_finished"))

func _on_attack_finished():
	if is_instance_valid(spear_hit_area):
		spear_hit_area.monitoring = false
		spear.hide()

func show_shield():
	shield.show()
	shield.get_node("CollisionShape2D").disabled = false

func hide_shield():
	shield.hide()
	shield.get_node("CollisionShape2D").disabled = true
