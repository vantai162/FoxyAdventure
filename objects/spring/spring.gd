@tool
extends Area2D
## Spring/Trampoline that launches player and enemies
## Launches in the direction the spring faces based on orientation
## 
## @tool script - orientation updates immediately in editor

enum Orientation {
	FLOOR,    ## Spring on floor, launches UP (default)
	CEILING,  ## Spring on ceiling, launches DOWN
	LEFT,     ## Spring on left wall, launches RIGHT
	RIGHT     ## Spring on right wall, launches LEFT
}

## Launch directions for each orientation (where entities get launched TO)
const LAUNCH_DIRECTIONS := {
	Orientation.FLOOR: Vector2(0, -1),    # Launch UP
	Orientation.CEILING: Vector2(0, 1),   # Launch DOWN
	Orientation.LEFT: Vector2(1, 0),      # Launch RIGHT
	Orientation.RIGHT: Vector2(-1, 0)     # Launch LEFT
}

@export var orientation := Orientation.FLOOR:
	set(value):
		orientation = value
		_apply_orientation()

@export var launch_force: float = 650.0  ## Force applied when launching

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Rotation angles for each orientation
const ROTATIONS := {
	Orientation.FLOOR: 0.0,
	Orientation.CEILING: PI,
	Orientation.LEFT: PI / 2,
	Orientation.RIGHT: -PI / 2
}

func _apply_orientation() -> void:
	if not is_inside_tree():
		return
	rotation = ROTATIONS.get(orientation, 0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		call_deferred("_apply_orientation")

func _ready() -> void:
	_apply_orientation()
	
	# Don't run gameplay logic in editor
	if Engine.is_editor_hint():
		return



func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemy"):
		animated_sprite.play("jump")
		
		# Get launch direction based on orientation
		var launch_dir: Vector2 = LAUNCH_DIRECTIONS.get(orientation, Vector2(0, -1))
		
		# Apply velocity in the correct direction
		if body.has_method("spring_launch"):
			# Use directional launch if available
			body.spring_launch(launch_dir * launch_force)
		else:
			# Fallback: apply velocity directly
			body.velocity = launch_dir * launch_force
		
		AudioManager.play_sound("power_up", 20.0)
		
		# Satisfying launch feedback — burst particles and camera shake
		_spawn_launch_feedback(launch_dir)
		if body.is_in_group("player"):
			var camera = body.get_node_or_null("Camera2D")
			if camera and camera.has_method("shake"):
				camera.shake(4.0)


## Spawn launch burst particles for satisfying spring feedback
func _spawn_launch_feedback(launch_dir: Vector2) -> void:
	var particles = GPUParticles2D.new()
	particles.amount = 6
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.one_shot = true
	particles.z_index = 5
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(launch_dir.x, launch_dir.y, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 0, 0)  # Particles follow launch direction
	mat.scale_min = 0.8
	mat.scale_max = 1.5
	mat.color = Color(1.0, 0.9, 0.3, 1.0)  # Yellow/gold spring color
	particles.process_material = mat
	
	# 4x4 texture per doctrine
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.6, 1.0))
	grad.set_color(1, Color(1.0, 0.8, 0.2, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 4
	tex.height = 4
	particles.texture = tex
	
	add_child(particles)
	particles.emitting = true
	
	# Cleanup
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "jump":
		animated_sprite.play("idle")
