extends Node2D
class_name Stalactite
## Stalactite Hazard - Ceiling spike that falls when triggered
## Multiple trigger modes: player proximity, random timer, or manual (for puzzles)
## Deals damage on contact, can optionally respawn

## Trigger mode determines how stalactite activates
enum TriggerMode {
	PLAYER_PROXIMITY,  ## Falls when player gets close (default)
	RANDOM_TIMER,      ## Falls at random intervals
	MANUAL             ## Only falls when trigger_fall() is called (puzzles)
}

@export_group("Trigger Settings")
@export var trigger_mode: TriggerMode = TriggerMode.PLAYER_PROXIMITY
@export var detection_radius: float = 80.0  ## How close player must be (PLAYER_PROXIMITY)
@export var detection_below_only: bool = true  ## Only trigger if player is below
@export var random_min_time: float = 3.0  ## Min time between falls (RANDOM_TIMER)
@export var random_max_time: float = 8.0  ## Max time between falls (RANDOM_TIMER)

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
@export var stalactite_texture: Texture2D = null  ## Assign sprite texture for GPU rendering (drawn pointing DOWN ↓)
@export var warning_particles: bool = true  ## Dust before falling
@export var stalactite_scale: float = 1.0  ## Size multiplier

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
	
	# Generate procedural sprite if no texture, or use GPU sprite if texture assigned
	if sprite:
		if stalactite_texture:
			_setup_sprite_texture()
		elif sprite.texture == null:
			push_warning("Stalactite: No stalactite_texture assigned - using CPU-rendered procedural fallback (assign Texture2D for production)")
			_create_procedural_stalactite()
	
	# Setup based on trigger mode
	match trigger_mode:
		TriggerMode.PLAYER_PROXIMITY:
			_setup_detection_area()
		TriggerMode.RANDOM_TIMER:
			_start_random_timer()
		TriggerMode.MANUAL:
			pass  # Wait for trigger_fall() call
	
	if hit_area:
		hit_area.damage = damage

func _setup_detection_area() -> void:
	if not detection_area:
		return
	
	detection_area.body_entered.connect(_on_detection_body_entered)
	# Set detection shape radius
	var circle = CircleShape2D.new()
	circle.radius = detection_radius
	if detection_area.has_node("CollisionShape2D"):
		detection_area.get_node("CollisionShape2D").shape = circle

func _start_random_timer() -> void:
	if current_state != State.IDLE:
		return
	
	var wait_time = randf_range(random_min_time, random_max_time)
	await get_tree().create_timer(wait_time).timeout
	
	if current_state == State.IDLE:
		_start_falling()


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
	
	# Restart random timer if in that mode
	if trigger_mode == TriggerMode.RANDOM_TIMER:
		_start_random_timer()

## Manual trigger (for puzzles or scripted events)
func trigger_fall() -> void:
	if current_state == State.IDLE:
		_start_falling()

## Reset to idle state
func reset() -> void:
	_respawn()

## Setup GPU sprite rendering (production mode)
func _setup_sprite_texture() -> void:
	if not sprite or not stalactite_texture:
		return
	
	sprite.texture = stalactite_texture
	sprite.scale = Vector2(stalactite_scale, stalactite_scale)
	sprite.visible = true
	# No rotation needed - sprite is drawn pointing DOWN ↓

## Create a simple procedural stalactite shape when no sprite is assigned
func _create_procedural_stalactite() -> void:
	var stalactite_poly = Polygon2D.new()
	stalactite_poly.name = "StalactiteShape"
	
	# Create pointed spike shape (pointing down)
	var width = 12.0 * stalactite_scale
	var height = 48.0 * stalactite_scale
	
	stalactite_poly.polygon = PackedVector2Array([
		Vector2(-width, 0),           # Top left
		Vector2(width, 0),            # Top right
		Vector2(width * 0.6, height * 0.3),  # Mid right
		Vector2(width * 0.3, height * 0.6),  # Lower right
		Vector2(0, height),           # Tip (bottom)
		Vector2(-width * 0.3, height * 0.6), # Lower left
		Vector2(-width * 0.6, height * 0.3), # Mid left
	])
	stalactite_poly.color = Color(0.5, 0.55, 0.6, 1.0)  # Stone gray
	add_child(stalactite_poly)
	
	# Add highlight
	var highlight = Polygon2D.new()
	highlight.name = "Highlight"
	highlight.polygon = PackedVector2Array([
		Vector2(-width * 0.3, 2),
		Vector2(0, 2),
		Vector2(0, height * 0.4),
		Vector2(-width * 0.2, height * 0.3),
	])
	highlight.color = Color(0.7, 0.72, 0.75, 0.5)
	add_child(highlight)
	
	# Hide the empty sprite
	sprite.visible = false
