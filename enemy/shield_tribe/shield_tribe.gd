extends EnemyCharacter
class_name ShieldTribe
## Shield-wielding tribe with reactive defense and spear attacks.
## Back-attack vulnerability, reactive jump blocking, turn delay, tween-based spear thrust.

@export_group("Combat")
@export var spear_damage: int = 1
@export var attack_interval: float = 2.0
@export var spear_thrust_distance: float = 30.0  ## How far the spear extends
@export var spear_thrust_out_time: float = 0.2  ## Time to thrust out
@export var spear_hold_time: float = 0.6  ## Time to hold extended (hit detection active)

# Calculated total attack duration (read-only, computed from thrust timings)
var attack_animation_duration: float:
	get:
		return spear_thrust_out_time + spear_hold_time

@export_group("Defense")
@export var jump_react_range: float = 60.0
@export var jump_react_velocity_threshold: float = -100.0  ## Minimum upward velocity to trigger block jump
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
	
	shield.hide()
	shield.get_node("CollisionShape2D").disabled = true
	spear.hide()
	spear_hit_area.monitoring = false

func _on_hurt_area_2d_hurt(attack_direction: Vector2, damage: float) -> void:
	if fsm.current_state.name == "defend" or fsm.current_state.name == "attack":
		# Direction points FROM attacker TO us
		var attacker_side = -sign(attack_direction.x)
		if attacker_side == 0:
			attacker_side = 1
		
		# If shield is blocking the attack, ignore damage
		if attacker_side == direction:
			return
	
	# Turn to face attacker if hit from behind (immediately, before knockback)
	# Direction points FROM attacker TO us, so negate to get attacker's position
	if attack_direction.x != 0:
		var attacker_side = -sign(attack_direction.x)
		if attacker_side != direction:
			change_direction(attacker_side)
	
	take_damage(damage)
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

		if desired == direction:
			return

		if _is_turning:
			_pending_direction = desired
			return

		_is_turning = true
		_pending_direction = desired
		var t = get_tree().create_timer(turn_delay)
		t.timeout.connect(Callable(self, "_on_turn_timeout"))

func _on_turn_timeout() -> void:
	if _pending_direction != 0:
		change_direction(_pending_direction)
	_pending_direction = 0
	_is_turning = false

func perform_spear_attack() -> void:
	spear.show()
	spear_sprite.play("attack")
	
	# Get the spear's initial position from the scene (not hardcoded!)
	var spear_start_pos = spear.position
	
	# Enable hit detection IMMEDIATELY when spear starts moving
	spear_hit_area.monitoring = true
	
	var tween = create_tween()
	tween.tween_property(spear, "position", spear_start_pos + Vector2(spear_thrust_distance, 0), spear_thrust_out_time)
	tween.tween_interval(spear_hold_time)
	tween.tween_callback(func(): 
		spear_hit_area.monitoring = false
		spear.hide()
		spear.position = spear_start_pos  # Reset to start position
	)

func show_shield() -> void:
	shield.show()
	shield.get_node("CollisionShape2D").disabled = false

func hide_shield() -> void:
	shield.hide()
	shield.get_node("CollisionShape2D").disabled = true

func darken_shield() -> void:
	for child in shield.get_children():
		if child is Sprite2D:
			child.modulate = Color(0.3, 0.3, 0.3, 1)

func restore_shield_color() -> void:
	for child in shield.get_children():
		if child is Sprite2D:
			child.modulate = Color(1, 1, 1, 1)
