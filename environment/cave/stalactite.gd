extends Node2D
## Stalactite Hazard - Ceiling spike that falls when player approaches
## Deals damage on contact, can optionally respawn

@export_group("Detection")
@export var detection_radius: float = 80.0  ## How close player must be to trigger
@export var detection_below_only: bool = true  ## Only trigger if player is below

@export_group("Fall Behavior")
@export var fall_delay: float = 0.3  ## Shake time before falling
@export var fall_speed: float = 500.0
@export var fall_acceleration: float = 800.0  ## Gravity during fall
@export var shake_intensity: float = 3.0

@export_group("Damage")
@export var damage: int = 1
@export var destroy_on_impact: bool = true
@export var respawn_time: float = 5.0  ## 0 = no respawn

@export_group("Visual")
@export var warning_particles: bool = true  ## Dust before falling

enum State { IDLE, SHAKING, FALLING, DESTROYED }
var current_state: State = State.IDLE
var velocity: float = 0.0
var original_position: Vector2
var original_x: float

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision: CollisionShape2D = $HitArea2D/CollisionShape2D if has_node("HitArea2D/CollisionShape2D") else null
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null
@onready var hit_area: HitArea2D = $HitArea2D if has_node("HitArea2D") else null
@onready var dust_particles: GPUParticles2D = $DustParticles if has_node("DustParticles") else null

func _ready() -> void:
	original_position = global_position
	original_x = position.x
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		# Set detection shape radius
		var circle = CircleShape2D.new()
		circle.radius = detection_radius
		if detection_area.has_node("CollisionShape2D"):
			detection_area.get_node("CollisionShape2D").shape = circle
	
	if hit_area:
		hit_area.damage = damage

func _physics_process(delta: float) -> void:
	match current_state:
		State.SHAKING:
			# Shake effect
			position.x = original_x + randf_range(-shake_intensity, shake_intensity)
		
		State.FALLING:
			velocity += fall_acceleration * delta
			position.y += velocity * delta
			
			# Check for ground collision
			if _check_ground_collision():
				_on_hit_ground()

func _on_detection_body_entered(body: Node2D) -> void:
	if current_state != State.IDLE:
		return
	
	if not body.is_in_group("player"):
		return
	
	# Check if player is below (if required)
	if detection_below_only and body.global_position.y < global_position.y:
		return
	
	_start_falling()

func _start_falling() -> void:
	current_state = State.SHAKING
	
	# Warning particles (dust)
	if warning_particles and dust_particles:
		dust_particles.emitting = true
	
	# Wait then fall
	await get_tree().create_timer(fall_delay).timeout
	
	if current_state == State.SHAKING:  # Still shaking (not reset)
		current_state = State.FALLING
		velocity = fall_speed * 0.5  # Initial fall speed
		position.x = original_x  # Stop shaking

func _check_ground_collision() -> bool:
	# Simple raycast down or use collision
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, 10),
		1  # Ground layer
	)
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func _on_hit_ground() -> void:
	current_state = State.DESTROYED
	velocity = 0.0
	
	# Disable hit detection
	if collision:
		collision.set_deferred("disabled", true)
	
	if destroy_on_impact:
		# Shatter effect (could add particles here)
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
			tween.tween_callback(_hide_and_respawn)
	else:
		# Stays on ground as obstacle
		if respawn_time > 0:
			await get_tree().create_timer(respawn_time).timeout
			_respawn()

func _hide_and_respawn() -> void:
	visible = false
	
	if respawn_time > 0:
		await get_tree().create_timer(respawn_time).timeout
		_respawn()

func _respawn() -> void:
	global_position = original_position
	position.x = original_x
	velocity = 0.0
	current_state = State.IDLE
	visible = true
	
	if sprite:
		sprite.modulate.a = 1.0
	if collision:
		collision.set_deferred("disabled", false)

## Manual trigger (for puzzles or scripted events)
func trigger_fall() -> void:
	if current_state == State.IDLE:
		_start_falling()

## Reset to idle state
func reset() -> void:
	_respawn()
