extends EnemyState

@export var burst_count: int = 3
@export var delay_between_shots: float = 0.9  ## Matches full animation cycle (4.5 frames / 5 FPS = 0.9s)
@export var shot_frame_time: float = 0.34  ## Time when barrel visually fires (frame 3: (0.8+0.9)/5.0 = 0.34s)

var shots_fired: int = 0
var burst_timer: float = 0.0
var waiting_for_shot: bool = false  ## Track if we're in wind-up before actual shot

func _enter() -> void:
	shots_fired = 0
	burst_timer = shot_frame_time
	waiting_for_shot = true
	_play_shoot_animation()  ## Force play animation from start

func _update(delta: float) -> void:
	burst_timer -= delta

	# Fire bullet when animation reaches fire frame
	if waiting_for_shot and burst_timer <= 0.0:
		fire_bullet()
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

func fire_bullet() -> void:
	var bullet := obj.bullet_factory.create() as RigidBody2D
	bullet.global_position = obj.global_position
	bullet.apply_impulse(Vector2(obj.bullet_speed * obj.direction, 0))
