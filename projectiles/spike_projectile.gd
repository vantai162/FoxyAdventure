class_name SpikeProjectile
extends Area2D
## Spike projectile for elite turtle spike burst
##
## SETUP: Assign texture to the Sprite2D child node in the editor.
## If no texture is assigned, a procedural fallback will be used (for prototyping).
## NOTE: Works with Node2DFactory for centralized spawning

@export var damage: int = 1
@export var speed: float = 180.0
@export var lifetime: float = 2.5
@export var spike_color: Color = Color(0.85, 0.85, 0.85, 1.0)  ## Only used if no texture on Sprite2D
@export var gravity_multiplier: float = 0.3  ## 30% of normal gravity for arc

var direction: Vector2  ## Set before adding to scene
var velocity: Vector2

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready():
	if direction == Vector2.ZERO:
		push_error("SpikeProjectile: direction not set before instantiation!")
		queue_free()
		return
	
	velocity = direction.normalized() * speed
	
	# Check if Sprite2D child has texture assigned
	if sprite and sprite.texture:
		sprite.centered = true
	elif sprite:
		# FALLBACK: Procedural visual for prototyping (CPU-rendered)
		push_warning("SpikeProjectile: No texture on Sprite2D child, using procedural fallback (assign Texture2D to Sprite2D for production)")
		var spike = Polygon2D.new()
		spike.polygon = PackedVector2Array([
			Vector2(0, -5),   # Tip
			Vector2(-2, 0),   # Base left
			Vector2(2, 0)     # Base right
		])
		spike.color = spike_color
		spike.z_index = ZLayers.PROJECTILE  # Match projectile layer
		add_child(spike)
		sprite.visible = false  # Hide empty sprite
	
	# Point spike in direction of travel
	# Sprite should be drawn pointing UP ↑, this rotates it to match direction
	rotation = direction.angle() + PI/2
	
	# Auto-destroy after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Damage on hit (Area2D collision system)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float):
	# Hitstop: freeze in place when hit lands
	if HitstopManager.is_frozen(self):
		return
	
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
