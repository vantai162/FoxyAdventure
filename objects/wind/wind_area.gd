extends Area2D
class_name WindArea
## Wind zone that pushes entities with proper visual feedback
## Features: horizontal speed streaks shader + dust particles
## Supports Channel System for puzzle integration (toggle on/off via lever)

## What to do when channel is activated
enum ChannelAction { ENABLE, DISABLE, TOGGLE }

@export_group("Channel System")
## Channel to listen to for activation/deactivation
@export var listen_channel: StringName = &""
## What happens when channel activates
@export var on_activate: ChannelAction = ChannelAction.DISABLE
## What happens when channel deactivates  
@export var on_deactivate: ChannelAction = ChannelAction.ENABLE

@export_group("Wind Settings")
@export var wind_force: Vector2 = Vector2(-150, 0)  ## Force applied per frame
@export var affect_enemies: bool = true  ## Push enemies too
@export var affect_projectiles: bool = false  ## Push projectiles
@export var enemy_force_multiplier: float = 0.5  ## Enemies resist wind more
@export var start_enabled: bool = true  ## Initial state

var _bodies_in_wind: Array[Node2D] = []
var _wind_streaks: ColorRect = null
var _dust_particles: GPUParticles2D = null
var _is_enabled: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Track node removals to clean stale body references (player death scenario)
	get_tree().node_removed.connect(_on_any_node_removed)
	
	# Get visual nodes
	_wind_streaks = get_node_or_null("WindStreaks")
	_dust_particles = get_node_or_null("DustParticles")
	
	# Configure visuals to match wind direction
	_configure_wind_visuals()
	
	# Set initial state
	_is_enabled = start_enabled
	_update_visual_state()
	
	# Register for channel events
	if not listen_channel.is_empty():
		var channel_manager = get_node_or_null("/root/InteractionChannel")
		if channel_manager:
			channel_manager.register_listener(listen_channel, _on_channel_activated, _on_channel_deactivated)

func _exit_tree() -> void:
	# Disconnect node removal tracking
	if get_tree() and get_tree().node_removed.is_connected(_on_any_node_removed):
		get_tree().node_removed.disconnect(_on_any_node_removed)
	
	# Disconnect from channel system
	if not listen_channel.is_empty():
		var channel_manager = get_node_or_null("/root/InteractionChannel")
		if channel_manager:
			channel_manager.unregister_listener(listen_channel, _on_channel_activated, _on_channel_deactivated)


func _on_any_node_removed(node: Node) -> void:
	# Clean stale body references when nodes are freed (e.g., player death)
	if _bodies_in_wind.has(node):
		_bodies_in_wind.erase(node)


func _on_channel_activated(_source: Node) -> void:
	match on_activate:
		ChannelAction.ENABLE: enable_wind()
		ChannelAction.DISABLE: disable_wind()
		ChannelAction.TOGGLE: toggle_wind()

func _on_channel_deactivated(_source: Node) -> void:
	match on_deactivate:
		ChannelAction.ENABLE: enable_wind()
		ChannelAction.DISABLE: disable_wind()
		ChannelAction.TOGGLE: toggle_wind()

func enable_wind() -> void:
	_is_enabled = true
	_update_visual_state()

func disable_wind() -> void:
	_is_enabled = false
	# Clear wind from any player currently in zone
	for body in _bodies_in_wind:
		if body.is_in_group("player") and "wind_velocity" in body:
			body.wind_velocity = Vector2.ZERO
	_update_visual_state()

func toggle_wind() -> void:
	if _is_enabled:
		disable_wind()
	else:
		enable_wind()

func _update_visual_state() -> void:
	if _wind_streaks:
		_wind_streaks.visible = _is_enabled
	if _dust_particles:
		_dust_particles.emitting = _is_enabled


func _configure_wind_visuals() -> void:
	## Sync visual direction with physics wind_force
	var wind_angle = wind_force.angle()
	
	# Update shader direction
	if _wind_streaks and _wind_streaks.material is ShaderMaterial:
		var mat = _wind_streaks.material as ShaderMaterial
		mat.set_shader_parameter("direction_angle", wind_angle)
		# Scale speed with force magnitude
		var speed_factor = wind_force.length() / 150.0
		mat.set_shader_parameter("wind_speed", 1.2 * speed_factor)
	
	# Update particle direction
	if _dust_particles and _dust_particles.process_material is ParticleProcessMaterial:
		var pmat = _dust_particles.process_material as ParticleProcessMaterial
		# Convert 2D angle to 3D direction for particles
		var dir_3d = Vector3(cos(wind_angle), sin(wind_angle), 0.0)
		pmat.direction = dir_3d
		# Scale velocity with force
		var base_vel = wind_force.length() * 0.8
		pmat.initial_velocity_min = base_vel * 0.6
		pmat.initial_velocity_max = base_vel * 1.2

func _physics_process(delta: float) -> void:
	## Apply wind to all tracked bodies (only when enabled)
	if not _is_enabled:
		return
	
	for body in _bodies_in_wind:
		if not is_instance_valid(body):
			continue
		_apply_wind_to_body(body, delta)



func _on_body_entered(body: Node2D) -> void:
	if body == null or not _is_enabled:
		return
	
	# Player - use wind_velocity property for smooth integration
	if body.is_in_group("player") and "wind_velocity" in body:
		body.wind_velocity = wind_force
		return
	
	# Track body for physics_process application
	if _should_affect_body(body):
		if not _bodies_in_wind.has(body):
			_bodies_in_wind.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body == null:
		return
	
	# Player - clear wind_velocity
	if body.is_in_group("player") and "wind_velocity" in body:
		body.wind_velocity = Vector2.ZERO
		return
	
	# Remove from tracking
	_bodies_in_wind.erase(body)

func _should_affect_body(body: Node2D) -> bool:
	## Determine if this body should be affected by wind
	if body.is_in_group("player"):
		return false  # Player handled separately via wind_velocity
	
	if body.is_in_group("enemy") and affect_enemies:
		return true
	
	if body.is_in_group("projectile") and affect_projectiles:
		return true
	
	return false

func _apply_wind_to_body(body: Node2D, delta: float) -> void:
	## Apply wind force directly to body velocity
	var force = wind_force * delta
	
	# Enemies resist wind more
	if body.is_in_group("enemy"):
		force *= enemy_force_multiplier
	
	# Apply to velocity if it exists
	if "velocity" in body:
		if body.velocity is Vector2:
			body.velocity += force
		return
	
	# Fallback: move position directly (for non-CharacterBody nodes)
	body.global_position += force
