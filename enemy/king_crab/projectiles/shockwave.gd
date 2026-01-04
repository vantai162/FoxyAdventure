extends Node2D
class_name Shockwave

## Expanding shockwave with IMMENSE seismic ring effect
## Uses shader-based concentric rings that expand outward like seismic waves
## Designed to feel like a FORCE - rings expand past camera edge and fade gracefully
##
## VISUAL vs GAMEPLAY SEPARATION:
## - Visual: Expands to 1.8x screen edge (cinematic, exits frame gracefully)
## - Collision: Only expands to gameplay_hit_radius (dodgeable AoE)
## - Once collision reaches max, it disables — rest is purely visual spectacle
##
## VISIBILITY MATH (1280x720 viewport):
## - Screen diagonal from center = ~734px (corner distance)
## - Shader has 5 rings with 0.15 spacing = last ring starts at expansion 0.6
## - For ALL rings to exit screen: animate expansion from 0 to 1.8

@export var expand_duration: float = 1.4  ## Time for full visual expansion
@export var screen_edge_radius: float = 740.0  ## Distance to screen corner from center
@export var max_expansion: float = 1.8  ## Visual expands to this (exits screen)
@export var gameplay_hit_radius: float = 60.0  ## ACTUAL damage range (tight, dodgeable!)
@export var damage: int = 1  ## Damage dealt to player
@export var knockback_force: float = 300.0  ## Force applied to player

@onready var hit_area: Area2D = $HitArea2D
@onready var collision_shape: CollisionShape2D = $HitArea2D/CollisionShape2D
@onready var visual: Sprite2D = $Visual

var _current_radius: float = 0.0
var _hit_bodies: Array = []  # Track who we've already hit
var _shader_material: ShaderMaterial = null
var _collision_disabled: bool = false


func _ready() -> void:
	# Get shader material for animation
	if visual and visual.material is ShaderMaterial:
		_shader_material = visual.material
	
	# Initialize at starting radius (not 0)
	_current_radius = 8.0
	_update_collision_radius(_current_radius)
	_update_expansion(0.0)  # Shader starts at 0 expansion
	
	# Scale visual so expansion=1.0 reaches screen edge
	# At max_expansion (1.8), visual will be 1.8x screen edge = well past corners
	if visual:
		var visual_radius = screen_edge_radius * max_expansion
		var visual_scale = visual_radius / 32.0  # Base texture is 64x64, so /32 for radius
		visual.scale = Vector2(visual_scale, visual_scale)
	
	# Calculate how long collision should be active
	# Collision reaches gameplay_hit_radius while visual continues to screen edge
	var collision_duration = expand_duration * (gameplay_hit_radius / (screen_edge_radius * max_expansion))
	
	# Animate VISUAL (shader expansion) — full cinematic duration
	var visual_tween = create_tween()
	visual_tween.set_ease(Tween.EASE_OUT)
	visual_tween.set_trans(Tween.TRANS_CUBIC)
	visual_tween.tween_method(_update_expansion, 0.0, max_expansion, expand_duration)
	visual_tween.tween_callback(_on_expansion_complete)
	
	# Animate COLLISION — only to gameplay range, then disable
	var collision_tween = create_tween()
	collision_tween.set_ease(Tween.EASE_OUT)
	collision_tween.set_trans(Tween.TRANS_CUBIC)
	collision_tween.tween_method(_update_collision_radius, 8.0, gameplay_hit_radius, collision_duration)
	collision_tween.tween_callback(_disable_collision)


func _update_expansion(value: float) -> void:
	## Animate the shader's expansion parameter (VISUAL ONLY)
	if _shader_material:
		_shader_material.set_shader_parameter("expansion", value)


func _update_collision_radius(radius: float) -> void:
	## Animate the collision shape (GAMEPLAY ONLY)
	_current_radius = radius
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius


func _disable_collision() -> void:
	## Collision has reached gameplay range — disable it, visual continues
	_collision_disabled = true
	if hit_area:
		hit_area.set_deferred("monitoring", false)
		hit_area.set_deferred("monitorable", false)


func _on_expansion_complete() -> void:
	# Fade out and despawn
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _on_hit_area_2d_body_entered(body: Node2D) -> void:
	# Only damage each body once per shockwave
	if body in _hit_bodies:
		return
	_hit_bodies.append(body)
	
	if body.is_in_group("player"):
		# Apply knockback away from center
		var knockback_dir = (body.global_position - global_position).normalized()
		if knockback_dir == Vector2.ZERO:
			knockback_dir = Vector2.UP
		
		# Check if player has hurt area
		if body.has_node("Direction/HurtArea2D"):
			var hurt_area = body.get_node("Direction/HurtArea2D")
			if hurt_area.has_method("take_damage"):
				hurt_area.take_damage(knockback_dir, damage)
		elif body.has_method("take_damage"):
			body.take_damage(damage)
			body.velocity = knockback_dir * knockback_force
		
		# Apply impulse momentum preservation so knockback isn't immediately braked
		if body.has_method("apply_impulse_momentum"):
			var horizontal_dir = sign(knockback_dir.x) as int
			body.apply_impulse_momentum(horizontal_dir)
