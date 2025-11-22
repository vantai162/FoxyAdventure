extends RigidBody2D

@export var speed: float = 350.0
@export var lift_force: float = -200.0 
@export var roll_speed: float = 200.0  
var direction := 1
var exploded: = false

@onready var sprite = $Sprite
@onready var explosion = $ExplosionSprite
@onready var flying_hitbox = $DirectionArea          
@onready var explosion_area = $HitArea2D 
@onready var explosion_hitbox = $HitArea2D/CollisionShape2D
@onready var timer = $Timer

func _ready() -> void:
	explosion.visible = false
	explosion_hitbox.set_deferred("disabled", true)
	explosion_area.monitoring = false
	apply_impulse(Vector2(-1*speed,lift_force))
	
func _integrate_forces(state):
	if exploded:
		return
	var vel = linear_velocity
	if (abs(vel.y) > 1.0):
		return
	vel.x = direction*roll_speed
	linear_velocity = vel
func explode():
	exploded = true
	linear_velocity = Vector2.ZERO
	gravity_scale = 0
	apply_impulse(Vector2.ZERO)
	sprite.visible = false
	explosion.visible = true
	explosion_hitbox.disabled = false
	timer.start()
	


func set_speed(_speed:float):
	speed= _speed
func set_lift_force(_lift_force:float):
	lift_force=_lift_force




func _on_timer_timeout() -> void:
	queue_free()


func _on_direction_area_body_entered(body: Node2D) -> void:
	explosion_hitbox.set_deferred("disabled", false)
	explosion_area.monitoring = true
