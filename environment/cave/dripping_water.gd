extends Node2D
## Dripping Water - Atmospheric cave effect
## Drops fall from origin, splash at splash_y_offset below
## Lifetime auto-calculated so drops visually reach the splash point

@export_group("Drip Settings")
@export var drip_rate: float = 2.0  ## Drops per second
@export var drop_speed: float = 150.0  ## Initial fall speed
@export var splash_y_offset: float = 100.0  ## Distance to splash point

@export_group("Visual")
@export var drop_color: Color = Color(0.6, 0.8, 1.0, 0.8)
@export var drop_size: float = 2.5

@export_group("Audio")
@export var play_drip_sound: bool = true
@export var sound_interval: float = 2.0

@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var splash_particles: GPUParticles2D = $SplashParticles if has_node("SplashParticles") else null
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null

var _sound_timer: float = 0.0
const GRAVITY: float = 300.0


func _ready() -> void:
	_setup_drop_particles()
	_setup_splash_particles()


func _process(delta: float) -> void:
	if play_drip_sound and audio:
		_sound_timer += delta
		if _sound_timer >= sound_interval:
			_sound_timer = randf_range(0.0, 0.5)  # Stagger next drip
			audio.pitch_scale = randf_range(0.9, 1.1)
			audio.play()


func _calculate_fall_time() -> float:
	## Physics: d = v0*t + 0.5*g*t² → solve for t using quadratic formula
	var discriminant := drop_speed * drop_speed + 2.0 * GRAVITY * splash_y_offset
	if discriminant < 0:
		return 1.5
	return (-drop_speed + sqrt(discriminant)) / GRAVITY + 0.05


func _setup_drop_particles() -> void:
	if not particles:
		return
	
	var lifetime := _calculate_fall_time()
	
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 3.0
	mat.initial_velocity_min = drop_speed
	mat.initial_velocity_max = drop_speed * 1.1
	mat.gravity = Vector3(0, GRAVITY, 0)
	mat.color = drop_color
	mat.scale_min = drop_size
	mat.scale_max = drop_size * 1.2
	
	particles.process_material = mat
	particles.amount = max(2, int(drip_rate * lifetime) + 1)
	particles.lifetime = lifetime
	particles.emitting = true


func _setup_splash_particles() -> void:
	if not splash_particles:
		return
	
	splash_particles.position.y = splash_y_offset
	
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 50.0
	mat.initial_velocity_min = 25.0
	mat.initial_velocity_max = 45.0
	mat.gravity = Vector3(0, 120, 0)
	mat.scale_min = 1.0
	mat.scale_max = 1.5
	mat.color = drop_color
	
	splash_particles.process_material = mat
	splash_particles.amount = 3
	splash_particles.lifetime = 0.3
	splash_particles.emitting = true


func set_active(active: bool) -> void:
	if particles:
		particles.emitting = active
	if splash_particles:
		splash_particles.emitting = active
