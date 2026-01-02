extends Player_State

## Swim entry splash — satisfying water immersion feedback
const WATER_SPLASH_SCENE: PackedScene = preload("res://assets/effects/dust_puff.tscn")

## Bubble trail settings — underwater ambiance
var bubble_timer: float = 0.0
const BUBBLE_INTERVAL: float = 0.4  ## Time between bubble spawns

func _enter():
	obj.change_animation("run")
	obj.gravity = obj.swim_gravity
	bubble_timer = 0.0
	
	# Splash on water entry!
	_spawn_water_splash()
	
	# Extinguish torch when entering water (can't hold torch while swimming!)
	var torch = obj.get_node_or_null("Direction/PlayerTorch")
	if torch and torch.is_lit:
		torch.extinguish("water")  # Pass reason for re-ignition logic


func _exit():
	# Exit splash when leaving water
	_spawn_water_splash()
	
	# When leaving swim state, try to re-ignite the torch if in darkness
	var torch = obj.get_node_or_null("Direction/PlayerTorch")
	if torch and torch.has_method("try_reignite"):
		torch.try_reignite()


func _update(delta: float):
	control_swimming()
	
	# Bubble trail while swimming underwater
	bubble_timer -= delta
	if bubble_timer <= 0 and obj.is_head_underwater():
		bubble_timer = BUBBLE_INTERVAL
		_spawn_bubble()
	
	# Check if head is underwater before depleting oxygen
	if obj.is_head_underwater():
		# Head is underwater - deplete oxygen
		obj.current_oxygen -= obj.oxygen_decrease_rate * delta
		if obj.current_oxygen <= 0:
			obj.current_oxygen = 0
			fsm.current_state.take_damage(1)
			obj.health_changed.emit()
	elif obj.current_water != null:
		# Head is above water surface - restore oxygen
		obj.current_oxygen = min(obj.max_oxygen, obj.current_oxygen + obj.oxygen_increase_rate * delta)
	
	# Exit swim state if no longer in water OR if head is above water (whirlpool air pockets)
	if not obj.is_in_water:
		fsm.change_state(fsm.states.fall)
	elif not obj.is_head_underwater() and obj.is_on_floor():
		# Standing in air pocket (like whirlpool depression) - return to ground movement
		fsm.change_state(fsm.states.idle)


## Spawn water splash on entry/exit — satisfying plunge feedback
func _spawn_water_splash() -> void:
	var splash = GPUParticles2D.new()
	splash.amount = 8
	splash.lifetime = 0.5
	splash.explosiveness = 1.0
	splash.one_shot = true
	splash.z_index = 25
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, -1, 0)  # Splash upward
	mat.spread = 60.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 150, 0)  # Fall back down
	mat.scale_min = 0.6
	mat.scale_max = 1.2
	mat.color = Color(0.7, 0.85, 1.0, 0.9)  # Water blue
	splash.process_material = mat
	
	# 4x4 texture per doctrine
	var grad = Gradient.new()
	grad.set_color(0, Color(0.9, 0.95, 1.0, 1.0))
	grad.set_color(1, Color(0.5, 0.7, 0.9, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 4
	tex.height = 4
	splash.texture = tex
	
	splash.global_position = obj.global_position
	get_tree().current_scene.add_child(splash)
	splash.emitting = true
	get_tree().create_timer(1.0).timeout.connect(splash.queue_free)


## Spawn underwater bubble — ambient swim feedback
func _spawn_bubble() -> void:
	var bubble = GPUParticles2D.new()
	bubble.amount = 2
	bubble.lifetime = 0.8
	bubble.explosiveness = 0.8
	bubble.one_shot = true
	bubble.z_index = 25
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, -1, 0)  # Rise up
	mat.spread = 20.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, -30, 0)  # Bubbles rise
	mat.scale_min = 0.4
	mat.scale_max = 0.8
	mat.color = Color(0.8, 0.9, 1.0, 0.7)
	bubble.process_material = mat
	
	# Tiny bubble texture
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.8))
	grad.set_color(1, Color(0.8, 0.9, 1.0, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 4
	tex.height = 4
	bubble.texture = tex
	
	# Spawn near player's head/mouth area
	bubble.global_position = obj.global_position + Vector2(obj.direction * 4, -8)
	get_tree().current_scene.add_child(bubble)
	bubble.emitting = true
	get_tree().create_timer(1.2).timeout.connect(bubble.queue_free)
	
