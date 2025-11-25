extends EnemyState

# Phase 2: Roll Bounce Attack (Bouncy rolling)

enum Phase { JUMPING, BOUNCING, LANDING }
var phase: Phase = Phase.JUMPING

var jump_velocity: Vector2 = Vector2(300, -400)
var bounce_count: int = 0
var max_bounces: int = 3
var bounce_velocity: float = 600.0

func _enter() -> void:
	phase = Phase.JUMPING
	bounce_count = 0
	
	# Initial jump
	obj.velocity = Vector2(obj.direction * jump_velocity.x, jump_velocity.y)
	obj.change_animation("roll") # Rolling animation while in air

func _update(delta: float) -> void:
	match phase:
		Phase.JUMPING:
			# Gravity handles the arc
			if obj.is_on_floor() and obj.velocity.y >= 0:
				_on_bounce()
		
		Phase.BOUNCING:
			if obj.is_on_floor() and obj.velocity.y >= 0:
				_on_bounce()

func _on_bounce() -> void:
	_create_shockwave()
	bounce_count += 1
	
	if bounce_count >= max_bounces:
		phase = Phase.LANDING
		_finish_attack()
	else:
		# Bounce again!
		phase = Phase.BOUNCING
		# Reverse direction sometimes? Or keep going? Let's keep going for now.
		# If hitting wall, turn around
		if obj.is_touch_wall():
			obj.turn_around()
			
		obj.velocity = Vector2(obj.direction * jump_velocity.x, -bounce_velocity)
		obj.change_animation("roll")

func _create_shockwave() -> void:
	# TODO: Create ground impact hitbox/effect
	pass

func _finish_attack() -> void:
	obj.velocity = Vector2.ZERO
	change_state(fsm.states.idle)
