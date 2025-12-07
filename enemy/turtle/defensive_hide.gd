extends EnemyState
## Elite Turtle "Spiny" defensive hide state
## Shoots 8 spikes in radial pattern, THEN hides (invulnerable)

@export var spike_projectile_scene: PackedScene  ## SpikeProjectile scene
@export var spike_burst_count: int = 8  ## Radial spikes (360° coverage)
@export var spike_speed: float = 200.0
@export var hide_duration: float = 2.5  ## Elite: Shorter than base hide (maintains pressure)

var hide_timer := 0.0
var spikes_fired := false

func _enter():
	obj.change_animation("hide")
	obj.velocity = Vector2.ZERO
	hide_timer = 0.0
	spikes_fired = false
	
	# Disable hurt area (invulnerability)
	if obj.has_node("Direction/HurtArea2D"):
		var hurt_area = obj.get_node("Direction/HurtArea2D")
		hurt_area.set_deferred("monitoring", false)
		hurt_area.set_deferred("monitorable", false)
	
	# Fire spike burst IMMEDIATELY on entry (porcupine defense)
	_fire_spike_burst()

func _update(delta: float) -> void:
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
	## Radial spike burst: 8 directions, 360° coverage
	if not spike_projectile_scene:
		push_warning("DefensiveHide: spike_projectile_scene not set!")
		return
	
	var angle_step = TAU / spike_burst_count  # 360° / 8 = 45° between spikes
	
	for i in range(spike_burst_count):
		var angle = i * angle_step
		var direction = Vector2(cos(angle), sin(angle))
		
		var spike = spike_projectile_scene.instantiate() as SpikeProjectile
		spike.direction = direction
		spike.speed = spike_speed
		
		# Add to scene
		get_tree().current_scene.add_child(spike)
		spike.global_position = obj.global_position
