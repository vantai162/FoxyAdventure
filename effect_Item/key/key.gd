extends Area2D
class_name KeyPickup
## Collectible key with optional ID for matching specific locks
## Designer-friendly: set key_id to match with doors/chests that require same ID

@export_group("Key Identity")
@export var key_id: String = "default"  ## Unique ID to match with locks (empty = generic key)
@export var key_color: Color = Color.YELLOW  ## Visual tint for the key sprite

@export_group("Pickup Effects")
@export var play_sound: bool = true
@export var show_particles: bool = true
@export var float_animation: bool = true
@export var float_amplitude: float = 4.0
@export var float_speed: float = 2.0

var _start_y: float = 0.0
var _time: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null

func _ready() -> void:
	if sprite:
		sprite.play("default")
		sprite.modulate = key_color
	
	_start_y = position.y
	_time = randf() * TAU  # Random phase for multiple keys
	
	# Connect area signal
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	if float_animation:
		_time += delta * float_speed
		position.y = _start_y + sin(_time) * float_amplitude

func _on_area_entered(area: Area2D) -> void:
	var player = area.get_parent()
	if not player is Player:
		return
	
	# Add key to inventory with ID
	if key_id.is_empty():
		player.inventory.adjust_amount_item("Key", 1)
	else:
		player.inventory.adjust_amount_item("Key_" + key_id, 1)
	
	# Visual/audio feedback using AudioManager
	if play_sound:
		AudioManager.play_sound("coin_collected", 15.0)
	
	if show_particles:
		_spawn_pickup_particles()
	
	# Hide immediately, cleanup after brief delay for particles
	visible = false
	set_process(false)
	
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _spawn_pickup_particles() -> void:
	## Create simple pickup particle effect
	var particles = GPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.5
	particles.global_position = global_position
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 8.0
	material.direction = Vector3(0, -1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.gravity = Vector3(0, 200, 0)
	material.color = key_color
	particles.process_material = material
	
	get_tree().current_scene.add_child(particles)
	
	# Auto-cleanup
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## Check if this key matches a specific lock ID
func matches_lock(lock_id: String) -> bool:
	if key_id.is_empty() or lock_id.is_empty():
		return true  # Generic keys match any lock
	return key_id == lock_id
