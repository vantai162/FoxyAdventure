extends RigidBody2D

@export var gravity := 900.0
var velocity := Vector2.ZERO
var direction := 1
var exploded: = false	

@onready var sprite = $Sprite2D
@onready var explosion: AnimatedSprite2D = $Explosion
@onready var flying_hitbox =       $ExplosionArea2D
@onready var explosion_area = $HitArea2D 
@onready var explosion_hitbox = $HitArea2D/CollisionShape2D
@onready var timer = $Timer

func _ready() -> void:
	explosion.visible = false
	explosion_hitbox.set_deferred("disabled", true)
	explosion_area.monitoring = false
	
func _physics_process(delta):
	if linear_velocity.length() > 1.0:
		sprite.rotation = linear_velocity.angle() + deg_to_rad(90)
		
func shoot(from: Vector2, to: Vector2, t: float):
	var dx = to.x - from.x
	var dy = to.y - from.y
	var vx = dx / t
	var vy = (dy - 0.5 * gravity * t * t) / t
	velocity = Vector2(vx, vy)
	linear_velocity = velocity
func explode():
	exploded = true
	linear_velocity = Vector2.ZERO
	gravity_scale = 0
	apply_impulse(Vector2.ZERO)
	sprite.visible=false
	explosion.visible = true
	explosion.play("default")
	explosion_hitbox.disabled = false
	timer.start()


func _on_timer_timeout() -> void:
	queue_free()

func _on_explosion_area_2d_body_entered(body: Node2D) -> void:
	print("hmm")
	explode()
	explosion_hitbox.set_deferred("disabled", false)
	explosion_area.monitoring = true
