extends EnemyState

## Base turtle Run state
## Periodic hide behavior: Turtle hides proactively every 6-8 seconds
@export var hide_interval_min: float = 6.0  ## Minimum time before hiding
@export var hide_interval_max: float = 8.0  ## Maximum time before hiding

var hide_timer: float = 0.0
var next_hide_time: float = 7.0  ## Set in _enter

func _enter() -> void:
	obj.change_animation("run")
	# Random interval between min and max for natural feel
	next_hide_time = randf_range(hide_interval_min, hide_interval_max)
	hide_timer = 0.0

func _update(delta):
	# Patrol movement
	obj.velocity.x = obj.direction * obj.movement_speed
	if _should_turn_around():
		obj.turn_around()
	
	# Periodic hide behavior (proactive, not just reactive)
	hide_timer += delta
	if hide_timer >= next_hide_time:
		# Base turtle: use Hide state
		# Elite turtle: use OffensiveHide if available, otherwise skip periodic hide
		if fsm.states.has("hide"):
			change_state(fsm.states.hide)
		elif fsm.states.has("offensivehide"):
			# Elite can use offensive hide periodically (but won't if on cooldown)
			if obj.has_method("can_burst") and obj.can_burst():
				change_state(fsm.states.offensivehide)
			else:
				# Reset timer and try again later
				hide_timer = 0.0
				next_hide_time = randf_range(hide_interval_min, hide_interval_max)

func _should_turn_around() -> bool:
	if obj.is_touch_wall():
		return true
	if obj.is_on_floor() and obj.is_can_fall():
		return true
	return false
