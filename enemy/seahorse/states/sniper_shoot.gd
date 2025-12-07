extends EnemyState
## Elite Seahorse "Sniper" shoot state
## Tracks player diagonally with smooth lerp (70% smoothness)
## Uses direct player reference from scene tree (stationary enemy doesn't need vision cone)

@export var burst_count: int = 5  ## Elite: 5 shots vs base 3 (66% more threat)
@export var delay_between_shots: float = 0.6  ## Elite: 0.6s vs base 0.75s (20% faster)
@export var first_shot_delay: float = 0.4  ## Elite: 0.4s vs base 0.5s (faster reaction)
@export var tracking_smoothness: float = 0.7  ## Higher = more threatening tracking
@export var detection_range: float = 600.0  ## Max distance to track player

var shots_fired: int = 0
var burst_timer: float = 0.0
var target_angle: float = 0.0  ## Calculated angle to player
var player: Player = null  ## Direct reference to player in scene

func _enter() -> void:
	shots_fired = 0
	burst_timer = first_shot_delay
	obj.change_animation("shoot")
	_find_player()

func _update(delta: float) -> void:
	# Continuously track player during burst
	_update_target_angle()
	
	burst_timer -= delta

	if burst_timer <= 0.0 and shots_fired < burst_count:
		fire_diagonal_bullet()
		shots_fired += 1
		burst_timer = delay_between_shots

	if shots_fired >= burst_count and burst_timer <= 0.0:
		change_state(fsm.states.idle)

func _find_player() -> void:
	## Get player reference from scene tree (simple approach for stationary enemy)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _update_target_angle() -> void:
	## Track player with smooth lerp - feels intelligent, not instant
	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null:
			target_angle = 0.0  # Default horizontal
			return
	
	# Check if player is in range
	var to_player = player.global_position - obj.global_position
	if to_player.length() > detection_range:
		target_angle = 0.0  # Out of range, shoot horizontal
		return
	
	var desired_angle = to_player.angle()
	
	# Smooth lerp for natural tracking feel
	target_angle = lerp_angle(target_angle, desired_angle, tracking_smoothness)

func fire_diagonal_bullet() -> void:
	## Fire bullet at current tracked angle
	var bullet := obj.bullet_factory.create() as RigidBody2D
	bullet.global_position = obj.global_position
	
	# Use tracked angle instead of horizontal-only
	var velocity = Vector2(cos(target_angle), sin(target_angle)) * obj.bullet_speed
	bullet.apply_impulse(velocity)
