extends Node2D
## Dripping Water - Atmospheric cave effect with optional puddle splash
## Uses GPUParticles2D for water drops falling from ceiling

@export_group("Drip Settings")
@export var drip_rate: float = 2.0  ## Drops per second
@export var drop_speed: float = 200.0  ## Fall speed
@export var drop_lifetime: float = 1.5  ## How long drops exist
@export var drop_spread: float = 8.0  ## Horizontal randomness

@export_group("Visual")
@export var drop_color: Color = Color(0.6, 0.8, 1.0, 0.8)  ## Light blue water
@export var drop_size: float = 3.0
@export var splash_on_ground: bool = true
@export var splash_y_offset: float = 100.0  ## Distance to ground for splash

@export_group("Audio")
@export var play_drip_sound: bool = true
@export var sound_interval: float = 1.5  ## Seconds between drip sounds

@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var splash_particles: GPUParticles2D = $SplashParticles if has_node("SplashParticles") else null
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null

var sound_timer: float = 0.0

func _ready() -> void:
	_setup_particles()
	if splash_on_ground and splash_particles:
		_setup_splash_particles()

func _process(delta: float) -> void:
	if play_drip_sound and audio:
		sound_timer += delta
		if sound_timer >= sound_interval:
			sound_timer = 0.0
			audio.pitch_scale = randf_range(0.9, 1.1)
			audio.play()

func _setup_particles() -> void:
	if not particles:
		return
	
	# Configure particle material for falling drops
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)  # Fall downward
	material.spread = 5.0
	material.initial_velocity_min = drop_speed * 0.8
	material.initial_velocity_max = drop_speed * 1.2
	material.gravity = Vector3(0, 400, 0)  # Additional gravity
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(drop_spread, 0, 0)
	material.color = drop_color
	material.scale_min = drop_size * 0.5
	material.scale_max = drop_size
	
	particles.process_material = material
	particles.amount = int(drip_rate * drop_lifetime) + 1
	particles.lifetime = drop_lifetime
	particles.emitting = true

func _setup_splash_particles() -> void:
	if not splash_particles:
		return
	
	splash_particles.position.y = splash_y_offset
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)  # Splash upward
	material.spread = 45.0
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	material.gravity = Vector3(0, 200, 0)
	material.scale_min = 1.0
	material.scale_max = 2.0
	material.color = drop_color
	
	splash_particles.process_material = material
	splash_particles.amount = 4
	splash_particles.lifetime = 0.4
	splash_particles.one_shot = false
	splash_particles.emitting = true

## Enable/disable the dripping effect
func set_active(active: bool) -> void:
	if particles:
		particles.emitting = active
	if splash_particles:
		splash_particles.emitting = active

## Change drip intensity (0.0 to 1.0)
func set_intensity(intensity: float) -> void:
	drip_rate = lerp(0.5, 5.0, clamp(intensity, 0.0, 1.0))
	if particles:
		particles.amount = int(drip_rate * drop_lifetime) + 1
