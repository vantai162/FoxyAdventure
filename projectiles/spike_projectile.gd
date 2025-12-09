class_name SpikeProjectile
extends Area2D
## Spike projectile for elite turtle spike burst
## PRODUCTION: Use sprite texture (GPU rendering, batchable)
## FALLBACK: Procedural Polygon2D if no texture assigned (prototyping only)
## NOTE: Works with Node2DFactory for centralized spawning

@export var spike_texture: Texture2D  ## ASSIGN SPRITE ASSET HERE (draw it pointing UP ↑)
@export var damage: int = 1
@export var speed: float = 180.0
@export var lifetime: float = 2.5
@export var spike_color: Color = Color(0.85, 0.85, 0.85, 1.0)  ## Only used if no texture
@export var gravity_multiplier: float = 0.3  ## 30% of normal gravity for arc

var direction: Vector2  ## Set before adding to scene
var velocity: Vector2

func _ready():
	if direction == Vector2.ZERO:
		push_error("SpikeProjectile: direction not set before instantiation!")
		queue_free()
		return
	
	velocity = direction.normalized() * speed
	
	# PRODUCTION: Use sprite texture (GPU rendering)
	if spike_texture:
		var sprite = Sprite2D.new()
		sprite.texture = spike_texture
		sprite.centered = true
		add_child(sprite)
	else:
		# FALLBACK: Procedural visual for prototyping (CPU-rendered)
		push_warning("SpikeProjectile: No texture assigned, using procedural fallback (NOT production-ready!)")
		var spike = Polygon2D.new()
		spike.polygon = PackedVector2Array([
			Vector2(0, -5),   # Tip
			Vector2(-2, 0),   # Base left
			Vector2(2, 0)     # Base right
		])
		spike.color = spike_color
		add_child(spike)
	
	# Point spike in direction of travel
	# Sprite should be drawn pointing UP ↑, this rotates it to match direction
	rotation = direction.angle() + PI/2
	
	# Collision shape (small circle for tip)
	var shape = CircleShape2D.new()
	shape.radius = 3.0
	var collision = CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	
	# Collision layers set in scene file (layer 16, mask 4)
	
	# Auto-destroy after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Damage on hit (Area2D collision system)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float):
	# Move projectile
	position += velocity * delta
	
	# Apply gravity for arc trajectory
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	velocity.y += gravity * gravity_multiplier * delta
	
	# Rotate to follow velocity direction (looks natural)
	rotation = velocity.angle() + PI/2

func _on_area_entered(area: Area2D):
	## Hit player's HurtArea2D (collision_layer = 4)
	if area.has_method("take_damage"):
		var hit_dir = area.global_position - global_position
		area.take_damage(hit_dir.normalized(), damage)
		queue_free()
