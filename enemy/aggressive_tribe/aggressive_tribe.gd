extends EnemyCharacter
class_name AggressiveTribe

@export_group("Throwing Behavior")
@export var throw_force: float = 350.0  ## Horizontal throw speed
@export var throw_arc: float = 400.0  ## Vertical component of throw velocity
@export var burst_cooldown: float = 2.0  ## Time between attack bursts
@export var burst_throw_interval: float = 0.25  ## Time between throws in a burst
@export var windup_time: float = 0.4  ## Preparation time before throwing

@export_group("Distance Scaling")
@export var distance_scale_factor: float = 250.0  ## Distance to normalize throw strength
@export var min_throw_multiplier: float = 0.7  ## Minimum throw force multiplier
@export var max_throw_multiplier: float = 1.6  ## Maximum throw force multiplier

@export_group("Projectiles")
@export var normal_coconut_scene: PackedScene
@export var special_coconut_scene: PackedScene

@onready var attack_timer: Timer = $AttackTimer
@onready var throw_timer: Timer = $ThrowTimer
@onready var windup_timer: Timer = $WindupTimer
@onready var throw_origin: Marker2D = $Direction/ThrowOrigin

func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()
	# Enable player detection
	enable_check_player_in_sight()
	
	# Set timer wait times from exports
	if attack_timer.wait_time == 0:
		attack_timer.wait_time = burst_cooldown
	if throw_timer.wait_time == 0:
		throw_timer.wait_time = burst_throw_interval
	if windup_timer.wait_time == 0:
		windup_timer.wait_time = windup_time
	
	# Connect timer signals
	throw_timer.timeout.connect(_on_throw_timer_timeout)
	windup_timer.timeout.connect(_on_windup_timer_timeout)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

# Override base behavior
func _on_player_in_sight(_player_pos: Vector2) -> void:
	if found_player:
		if found_player.global_position.x > global_position.x:
			change_direction(1)
		else:
			change_direction(-1)
	
	# Trigger attack if not already attacking or winding up
	if fsm.current_state == fsm.states.run and attack_timer.is_stopped():
		_on_attack_timer_timeout()

func _on_player_not_in_sight() -> void:
	# Return to run state if attacking or winding up
	if fsm.current_state == fsm.states.attack or fsm.current_state == fsm.states.windup:
		attack_timer.stop()
		fsm.change_state(fsm.states.run)

func _on_attack_timer_timeout() -> void:
	fsm.change_state(fsm.states.windup)

func _on_throw_timer_timeout() -> void:
	if fsm.current_state.has_method("_on_throw_timer_timeout"):
		fsm.current_state._on_throw_timer_timeout()

func _on_windup_timer_timeout() -> void:
	if fsm.current_state.has_method("_on_windup_timer_timeout"):
		fsm.current_state._on_windup_timer_timeout()

# Helper method for states to use
func throw_coconut(scene: PackedScene, pos: Vector2, velocity: Vector2) -> void:
	var coconut = scene.instantiate() as RigidBody2D
	get_tree().current_scene.add_child(coconut)
	coconut.global_position = pos
	if coconut.has_method("launch"):
		coconut.launch(velocity)
