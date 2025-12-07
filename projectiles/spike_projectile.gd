class_name SpikeProjectile
extends Area2D
## Procedural spike projectile - reusable for any enemy
## Asset-free: Uses Polygon2D triangles
## Physics: Gravity-affected arc trajectory

@export var damage: int = 1
@export var speed: float = 180.0
@export var lifetime: float = 2.5
@export var spike_color: Color = Color(0.85, 0.85, 0.85, 1.0)
@export var gravity_multiplier: float = 0.3  ## 30% of normal gravity for arc

var direction: Vector2  ## Set before adding to scene
var velocity: Vector2

func _ready():
	if direction == Vector2.ZERO:
		push_error("SpikeProjectile: direction not set before instantiation!")
		queue_free()
		return
	
	velocity = direction.normalized() * speed
	
	# Procedural visual: Triangle spike
	var spike = Polygon2D.new()
	spike.polygon = PackedVector2Array([
		Vector2(0, -5),   # Tip
		Vector2(-2, 0),   # Base left
		Vector2(2, 0)     # Base right
	])
	spike.color = spike_color
	add_child(spike)
	
	# Point spike in direction of travel
	rotation = direction.angle() + PI/2
	
	# Collision shape (small circle for tip)
	var shape = CircleShape2D.new()
	shape.radius = 3.0
	var collision = CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	
	# Collision layers
	collision_layer = 16  # Enemy projectile layer
	collision_mask = 4    # Player layer
	
	# Auto-destroy after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Damage on hit
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float):
	# Move projectile
	position += velocity * delta
	
	# Apply gravity for arc trajectory
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	velocity.y += gravity * gravity_multiplier * delta
	
	# Rotate to follow velocity direction (looks natural)
	rotation = velocity.angle() + PI/2

func _on_body_entered(body: Node2D):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
