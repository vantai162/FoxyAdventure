extends Player_State

## Stun stars particle — dazed visual feedback
var stun_particles: GPUParticles2D = null

func _enter() -> void:
	obj.change_animation("stun")
	obj.stun_ani.visible = true
	obj.stun_ani.play("default")
	obj.velocity.x=0
	
	# Camera shake on stun entry
	var camera = obj.get_node_or_null("Camera2D")
	if camera and camera.has_method("shake"):
		camera.shake(3.0)
	
	# Spawn circling star particles
	_spawn_stun_stars()

func _exit() -> void:
	# Cleanup stun particles
	if stun_particles and is_instance_valid(stun_particles):
		stun_particles.emitting = false
		stun_particles.queue_free()
		stun_particles = null

func _update(delta: float) -> void:
	obj._updateeffect(delta)
	if obj.Effect["Stun"] <= 0:
		obj.stun_ani.visible = false
		change_state(fsm.states.idle)


## Spawn circling stun stars — classic dazed effect
func _spawn_stun_stars() -> void:
	stun_particles = GPUParticles2D.new()
	stun_particles.amount = 4
	stun_particles.lifetime = 1.5
	stun_particles.preprocess = 0.5
	stun_particles.z_index = 30  # Above player
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 12.0
	mat.emission_ring_inner_radius = 10.0
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 0.0
	mat.orbit_velocity_min = 0.5
	mat.orbit_velocity_max = 0.6
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.6
	mat.scale_max = 1.0
	mat.color = Color(1.0, 1.0, 0.4, 0.9)  # Yellow stars
	stun_particles.process_material = mat
	
	# Tiny star texture
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.6, 1.0))
	grad.set_color(1, Color(1.0, 0.9, 0.3, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 4
	tex.height = 4
	stun_particles.texture = tex
	
	# Position above player's head
	stun_particles.position = Vector2(0, -20)
	obj.add_child(stun_particles)
	stun_particles.emitting = true
