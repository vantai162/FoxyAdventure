extends Node2D
class_name Shockwave

## Expanding shockwave damage area - used for ground pound attacks

@export var expand_duration: float = 0.3  ## How long the shockwave expands
@export var max_radius: float = 80.0  ## Maximum radius of the shockwave
@export var damage: int = 1  ## Damage dealt to player
@export var knockback_force: float = 300.0  ## Force applied to player

@onready var hit_area: Area2D = $HitArea2D
@onready var collision_shape: CollisionShape2D = $HitArea2D/CollisionShape2D
@onready var visual: Sprite2D = $Visual

var _current_radius: float = 0.0
var _hit_bodies: Array = []  # Track who we've already hit


func _ready() -> void:
	# Start small
	_current_radius = 8.0
	_update_radius(_current_radius)
	
	# Expand outward
	var tween = create_tween()
	tween.tween_method(_update_radius, _current_radius, max_radius, expand_duration)
	tween.tween_callback(_on_expansion_complete)


func _update_radius(radius: float) -> void:
	_current_radius = radius
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius
	
	# Scale visual to match
	if visual:
		var scale_factor = radius / 16.0  # Assuming base sprite is 32x32
		visual.scale = Vector2(scale_factor, scale_factor)


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
