extends EnemyState
## Elite Turtle "Spiny" offensive hide state
## Telegraph → 120° upward cone spike burst → hide (invulnerable)
## Design: Clear telegraph (stops to wind up) = intuitive, readable attack

@export var spike_burst_count: int = 6  ## 120° cone (20° spacing)
@export var spike_speed: float = 200.0
@export var hide_duration: float = 2.5  ## Elite: Shorter than base hide (maintains pressure)
@export var telegraph_duration: float = 0.35  ## Balanced windup - fast but readable

var hide_timer := 0.0
var telegraph_timer := 0.0
var spikes_fired := false
var is_telegraphing := false

func _enter():
	obj.change_animation("hide")
	# STOP to wind up attack - INTUITIVE: Turtle plants feet, retracts into shell
	# Clear telegraph = player can read and dodge
	obj.velocity = Vector2.ZERO
	hide_timer = 0.0
	telegraph_timer = 0.0
	spikes_fired = false
	is_telegraphing = true
	
	# Stay vulnerable during telegraph (commitment risk)
	# Invulnerability applied AFTER spikes fire

func _update(delta: float) -> void:
	if is_telegraphing:
		# TELEGRAPH PHASE: Stationary windup (clear, readable)
		telegraph_timer += delta
		if telegraph_timer >= telegraph_duration:
			# Telegraph complete → FIRE SPIKES
			is_telegraphing = false
			_fire_spike_burst()
			# Mark burst cooldown
			obj.mark_burst_used()
			# NOW become invulnerable
			if obj.has_node("Direction/HurtArea2D"):
				var hurt_area = obj.get_node("Direction/HurtArea2D")
				hurt_area.set_deferred("monitoring", false)
				hurt_area.set_deferred("monitorable", false)
	else:
		# HIDE PHASE: Invulnerable, stationary, waiting
		hide_timer += delta
		if hide_timer >= hide_duration:
			change_state(fsm.default_state)

func _exit() -> void:
	# Re-enable hurt area
	if obj.has_node("Direction/HurtArea2D"):
		var hurt_area = obj.get_node("Direction/HurtArea2D")
		hurt_area.set_deferred("monitoring", true)
		hurt_area.set_deferred("monitorable", true)

func _fire_spike_burst() -> void:
	## 120° UPWARD cone burst: Spikes arc up and rain down with gravity
	## Pattern: -60° to +60° from straight UP (like Chinese handheld fan)
	if not obj.spike_projectile_scene:
		push_warning("OffensiveHide: spike_projectile_scene not set on character!")
		return
	
	var cone_start_angle = -PI/2 - PI/3  # UP (-90°) - 60° = -150°
	var cone_end_angle = -PI/2 + PI/3    # UP (-90°) + 60° = -30°
	var cone_range = cone_end_angle - cone_start_angle  # 120° total
	var angle_step = cone_range / (spike_burst_count - 1)  # Spacing between spikes
	
	for i in range(spike_burst_count):
		var angle = cone_start_angle + (i * angle_step)
		var direction = Vector2(cos(angle), sin(angle))
		
		var spike = obj.spike_projectile_scene.instantiate() as SpikeProjectile
		spike.direction = direction
		spike.speed = spike_speed
		
		# Add to scene
		get_tree().current_scene.add_child(spike)
		# Spawn from turtle center (shell position during hide animation)
		spike.global_position = obj.global_position + Vector2(0, -2)  # Slightly above center
