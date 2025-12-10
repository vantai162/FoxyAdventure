extends EnemyState
## Tracks player diagonally with smooth lerp (70% smoothness)
## Uses detection area reference - only tracks player while in forward cone

@export var burst_count: int = 5  ## Elite: 5 shots vs base 3 (66% more threat)
@export var delay_between_shots: float = 0.75  ## Elite: Faster than base 0.9s (elite fires faster bursts)
@export var shot_frame_time: float = 0.34  ## Time when barrel visually fires (frame 3: (0.8+0.9)/5.0 = 0.34s)
@export var tracking_smoothness: float = 0.7  ## Higher = more threatening tracking
@export var detection_range: float = 600.0  ## Max distance to track player

var shots_fired: int = 0
var burst_timer: float = 0.0
var target_angle: float = 0.0  ## Calculated angle to player
var waiting_for_shot: bool = false  ## Track if we're in wind-up before actual shot

func _enter() -> void:
	shots_fired = 0
	burst_timer = shot_frame_time
	waiting_for_shot = true
	_play_shoot_animation()  ## Force play animation from start

func _update(delta: float) -> void:
	# Check if player left detection area - abort burst immediately
	if obj.found_player == null:
		change_state(fsm.states.idle)
		return
	
	# Continuously track player during burst
	_update_target_angle()
	
	burst_timer -= delta

	# Fire bullet when animation reaches fire frame
	if waiting_for_shot and burst_timer <= 0.0:
		fire_diagonal_bullet()
		shots_fired += 1
		waiting_for_shot = false
		
		# If more shots remain, prepare next shot cycle
		if shots_fired < burst_count:
			burst_timer = delay_between_shots
		else:
			# All shots fired, wait for animation to finish then return to idle
			burst_timer = delay_between_shots - shot_frame_time  # Wait remaining animation time
	
	# Start next shot animation cycle
	elif not waiting_for_shot and burst_timer <= 0.0:
		if shots_fired < burst_count:
			_play_shoot_animation()  ## Force replay animation from start
			burst_timer = shot_frame_time
			waiting_for_shot = true
		else:
			# Burst complete, return to idle
			change_state(fsm.states.idle)

func _play_shoot_animation() -> void:
	## Direct call to AnimatedSprite2D.play() to force restart animation from frame 0
	## CRITICAL: Sync BOTH _next_animation and current_animation to prevent system from overwriting!
	if obj.animated_sprite:
		obj.animated_sprite.play("shoot")
		obj.current_animation = "shoot"  # Sync current state
		obj._next_animation = "shoot"    # Sync next state (prevents overwrite on next frame)

func _update_target_angle() -> void:
	## Track player with smooth lerp using detection-based reference
	## Only tracks if player is in forward detection cone (DetectPlayerArea2D)
	if obj.found_player == null or not is_instance_valid(obj.found_player):
		target_angle = 0.0  # No player detected, default horizontal
		return
	
	# Check if player is in range
	var to_player = obj.found_player.global_position - obj.global_position
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
