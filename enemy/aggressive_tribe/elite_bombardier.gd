extends EnemyCharacter
class_name EliteBombardier
## Elite Aggressive Tribe: "The Bombardier"
## ALL coconuts are slowing coconuts - overwhelming zone control
## Lightning-fast timing creates relentless pressure
## ACTIVELY PURSUES player - maintains optimal throw range

@export_group("Throwing Behavior")
@export var throw_force: float = 550.0  ## Faster, straighter trajectory (reduced arc hitting ceilings)
@export var throw_arc: float = 400.0  ## Vertical component of throw velocity (unused in ballistic calc)

@export_group("Distance Scaling")
@export var distance_scale_factor: float = 250.0  ## Distance to normalize throw strength
@export var min_throw_multiplier: float = 0.7  ## Minimum throw force multiplier
@export var max_throw_multiplier: float = 1.6  ## Maximum throw force multiplier

@export_group("Projectiles")
@export var special_coconut_scene: PackedScene  ## Elite ONLY uses slowing coconuts

@onready var attack_timer: Timer = $AttackTimer  ## Wait: 1.0s (set in scene)
@onready var throw_timer: Timer = $ThrowTimer  ## Wait: 0.2s (set in scene)
@onready var windup_timer: Timer = $WindupTimer  ## Wait: 0.3s (set in scene)
@onready var throw_origin: Marker2D = $Direction/ThrowOrigin

## Attack commitment system - prevents abort kiting
var is_committed_to_attack: bool = false
var last_known_player_pos: Vector2 = Vector2.ZERO
var last_known_player_dir: int = 1

func _ready() -> void:
	# Initialize FSM with pursue state for elite behavior
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()
	enable_check_player_in_sight()
	
	# Elite only uses slowing coconuts
	if not special_coconut_scene:
		push_error("EliteBombardier: special_coconut_scene REQUIRED! Assign SlowingCoconut scene.")
	
	# Connect timer signals
	throw_timer.timeout.connect(_on_throw_timer_timeout)
	windup_timer.timeout.connect(_on_windup_timer_timeout)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

# Override to use pursue state instead of passive patrol
func _on_player_in_sight(_player_pos: Vector2) -> void:
	if found_player:
		if found_player.global_position.x > global_position.x:
			change_direction(1)
		else:
			change_direction(-1)
	
	# Elite behavior: Pursue player aggressively
	if fsm.current_state == fsm.states.run:
		if fsm.states.has("pursue"):
			fsm.change_state(fsm.states.pursue)
		else:
			# Fallback to base behavior if pursue state missing
			if attack_timer.is_stopped():
				_on_attack_timer_timeout()

func _on_player_not_in_sight() -> void:
	# Return to patrol when player lost (only if not committed to attack)
	if fsm.current_state == fsm.states.pursue:
		fsm.change_state(fsm.states.run)
	# DON'T override attack/windup abort - let base commitment system handle it
	# Base class has empty _on_player_not_in_sight() to prevent aborting committed attacks

func _on_attack_timer_timeout() -> void:
	fsm.change_state(fsm.states.windup)

func _on_throw_timer_timeout() -> void:
	if fsm and fsm.current_state and fsm.current_state.has_method("_on_throw_timer_timeout"):
		fsm.current_state._on_throw_timer_timeout()

func _on_windup_timer_timeout() -> void:
	if fsm and fsm.current_state and fsm.current_state.has_method("_on_windup_timer_timeout"):
		fsm.current_state._on_windup_timer_timeout()

# Helper method for states to use
func throw_coconut(scene: PackedScene, pos: Vector2, velocity: Vector2) -> void:
	var coconut = scene.instantiate() as RigidBody2D
	get_tree().current_scene.add_child(coconut)
	coconut.global_position = pos
	if coconut.has_method("launch"):
		coconut.launch(velocity)
