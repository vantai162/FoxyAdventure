extends Player_State

## Idle breathing — subtle life in stillness
## CRITICAL: Use relative scale to preserve facing direction
const BREATH_SCALE_Y_MIN: float = 0.98
const BREATH_SCALE_Y_MAX: float = 1.02
const BREATH_DURATION: float = 1.2  ## Full breath cycle

## Bored fidget timing — fox looks around after idle
const FIDGET_DELAY: float = 4.0  ## Seconds before fidget
var idle_timer: float = 0.0
var breathing_tween: Tween = null

func _enter() -> void:
	# Don't force velocity to 0 - let control_moving() handle deceleration
	# This allows ice sliding and other physics to work naturally
	obj.change_animation("idle")
	idle_timer = 0.0
	_start_breathing()

func _exit() -> void:
	# Stop breathing animation and reset scale
	if breathing_tween and breathing_tween.is_valid():
		breathing_tween.kill()
	breathing_tween = null
	_cleanup_scale_tween()  # Use shared cleanup

func _update(delta: float) -> void:
	obj.current_oxygen = min(obj.max_oxygen, obj.current_oxygen + obj.oxygen_increase_rate * delta)
	control_throw()
	control_attack()
	control_moving()
	control_jump()
	
	# Track idle time for fidget
	idle_timer += delta
	if idle_timer >= FIDGET_DELAY:
		idle_timer = 0.0
		_do_fidget()
	
	if not obj.is_on_floor():
		change_state(fsm.states.fall)


## Start subtle breathing animation — life in stillness
## CRITICAL: Only animate Y scale to preserve X direction!
func _start_breathing() -> void:
	var direction_node = obj.get_node_or_null("Direction")
	if not direction_node:
		return
	
	breathing_tween = create_tween()
	breathing_tween.set_loops()  # Infinite loop
	# Only tween scale.y — DO NOT touch scale.x (direction)!
	breathing_tween.tween_property(direction_node, "scale:y", BREATH_SCALE_Y_MAX, BREATH_DURATION * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	breathing_tween.tween_property(direction_node, "scale:y", BREATH_SCALE_Y_MIN, BREATH_DURATION * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## Fidget when idle too long — fox is alive, not a statue
## DRAMATIC squash/stretch to be clearly visible
func _do_fidget() -> void:
	var direction_node = obj.get_node_or_null("Direction")
	if not direction_node:
		return
	
	# Stop breathing briefly for fidget
	if breathing_tween and breathing_tween.is_valid():
		breathing_tween.pause()
	
	# Preserve facing direction
	var facing = sign(direction_node.scale.x) if direction_node.scale.x != 0 else 1.0
	
	var fidget_tween = create_tween()
	# DRAMATIC anticipation squash (20% compression) → stretch up (15%) → settle
	# This is a "look around" gesture that's actually VISIBLE
	fidget_tween.tween_property(direction_node, "scale", Vector2(facing * 1.15, 0.80), 0.12).set_ease(Tween.EASE_OUT)
	fidget_tween.tween_property(direction_node, "scale", Vector2(facing * 0.90, 1.15), 0.15).set_ease(Tween.EASE_OUT)
	fidget_tween.tween_property(direction_node, "scale", Vector2(facing * 1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	fidget_tween.tween_callback(func():
		if breathing_tween and breathing_tween.is_valid():
			breathing_tween.play()
	)
