extends EnemyCharacter
class_name AggressiveTribe

# Throwing behavior
@export var throw_force: float = 200.0
@export var burst_cooldown: float = 3.0
@export var burst_throw_interval: float = 0.3
@export var windup_time: float = 0.5

# Projectile scenes (assign in editor)
@export var normal_coconut_scene: PackedScene
@export var special_coconut_scene: PackedScene

@onready var attack_timer: Timer = $AttackTimer
@onready var throw_timer: Timer = $ThrowTimer
@onready var windup_timer: Timer = $WindupTimer
@onready var throw_origin: Marker2D = $Direction/ThrowOrigin

var throw_count: int = 0
var is_attacking: bool = false
var is_winding_up: bool = false

func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()
	
	if attack_timer.wait_time == 0:
		attack_timer.wait_time = burst_cooldown
	if throw_timer.wait_time == 0:
		throw_timer.wait_time = burst_throw_interval
	if windup_timer.wait_time == 0:
		windup_timer.wait_time = windup_time

	if attack_timer.timeout.is_connected(self._on_throw_timer_timeout):
		attack_timer.timeout.disconnect(self._on_throw_timer_timeout)
	if not attack_timer.timeout.is_connected(self._on_attack_timer_timeout):
		attack_timer.timeout.connect(self._on_attack_timer_timeout)
	
	if windup_timer.timeout.is_connected(self._on_throw_timer_timeout):
		windup_timer.timeout.disconnect(self._on_throw_timer_timeout)
	if not windup_timer.timeout.is_connected(self._on_windup_timer_timeout):
		windup_timer.timeout.connect(self._on_windup_timer_timeout)

# Override base behavior
func _on_player_in_sight(_player_pos: Vector2) -> void:
	if found_player:
		if found_player.global_position.x > global_position.x:
			change_direction(1)
		else:
			change_direction(-1)
	
	if not is_attacking and not is_winding_up and attack_timer.is_stopped():
		_on_attack_timer_timeout()

func _on_player_not_in_sight() -> void:
	if is_attacking or is_winding_up:
		return
	
	attack_timer.stop()
	throw_timer.stop()
	windup_timer.stop()
	throw_count = 0

func _on_attack_timer_timeout() -> void:
	is_winding_up = true
	throw_count = 0
	
	if found_player:
		if found_player.global_position.x > global_position.x:
			change_direction(1)
		else:
			change_direction(-1)
	
	windup_timer.start()

func _on_windup_timer_timeout() -> void:
	is_winding_up = false
	is_attacking = true
	_throw_next_coconut()

func _on_throw_timer_timeout() -> void:
	_throw_next_coconut()

func _throw_next_coconut() -> void:
	throw_count += 1
	
	var coconut_scene = special_coconut_scene if throw_count == 3 else normal_coconut_scene
	if not coconut_scene:
		return
	
	var launch_velocity_y = -300.0
	var launch_velocity_x: float
	if found_player:
		var dx = found_player.global_position.x - global_position.x
		var dist = abs(dx)
		var factor = clamp(dist / 200.0, 0.6, 1.4)
		launch_velocity_x = throw_force * factor * direction
	else:
		launch_velocity_x = throw_force * direction
	
	_throw_coconut(coconut_scene, throw_origin.global_position, Vector2(launch_velocity_x, launch_velocity_y))
	
	if throw_count >= 3:
		is_attacking = false
		if found_player:
			attack_timer.start()
	else:
		throw_timer.start()

func _throw_coconut(scene: PackedScene, pos: Vector2, velocity: Vector2) -> void:
	var coconut = scene.instantiate() as RigidBody2D
	get_tree().current_scene.add_child(coconut)
	coconut.global_position = pos
	if coconut.has_method("launch"):
		coconut.launch(velocity)
