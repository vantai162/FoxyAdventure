extends HitArea2D
class_name AirSlash

# Movement properties (configured by spawner)
var initial_speed: float = 300.0
var deceleration: float = 500.0
var min_speed: float = 0.0

# Timing: fade_in -> active (full opacity + damage) -> fade_out -> destroy
var fade_in_time: float = 0.1      # How long to fade in
var active_time: float = 0.3       # How long to stay fully visible and damaging
var fade_out_time: float = 0.3     # How long to fade out
var total_time: float = 0.8        # Total lifetime before destruction

# Internal state
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.0
var attack_direction: Vector2 = Vector2.ZERO  # Direction of attack for damage calculation
var collision_shape: CollisionShape2D

func _init() -> void:
	super._init()

func _enter_tree() -> void:
	collision_shape = get_node_or_null("CollisionShape2D")
	modulate.a = 0.0

func launch(direction: int) -> void:
	velocity = Vector2(initial_speed * direction, 0)
	# Attack direction points FROM attacker (player) TO target (enemy)
	# This matches the direction the air slash is traveling
	attack_direction = Vector2(direction, 0).normalized()
	scale.x = direction

# Override parent hit method to use attack direction instead of position-based calculation
func hit(hurt_area):
	if hurt_area.has_method("take_damage"):
		# Pass attack direction (FROM attacker TO target)
		# Shields check if attacker_side (-sign(direction.x)) matches their facing
		hurt_area.take_damage(attack_direction, damage)

func _process(delta: float) -> void:
	lifetime += delta
	
	# Movement with deceleration
	if velocity.length() > min_speed:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	
	position += velocity * delta
	
	# Calculate timing phases
	var fade_out_start = fade_in_time + active_time
	
	# Fade in/out
	if lifetime < fade_in_time:
		modulate.a = lifetime / fade_in_time
	elif lifetime < fade_out_start:
		modulate.a = 1.0
	else:
		var fade_progress = (lifetime - fade_out_start) / fade_out_time
		modulate.a = 1.0 - clamp(fade_progress, 0.0, 1.0)
	
	# Disable collision when fading out (after active time)
	if lifetime >= fade_out_start and collision_shape and not collision_shape.disabled:
		collision_shape.set_deferred("disabled", true)
	
	# Cleanup
	if lifetime >= total_time:
		queue_free()
