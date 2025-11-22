extends RigidBody2D

@export var speed: float = 400.0
@export var lift_force: float = -200.0 
@export var roll_speed: float = 200.0  
var direction := 1

func _ready() -> void:
	apply_impulse(Vector2(-1*speed,lift_force))
	
func _integrate_forces(state):
	var vel = linear_velocity
	if (abs(vel.y) > 1.0):
		return
	vel.x = direction*roll_speed
	linear_velocity = vel
func _on_body_entered(body):
	queue_free()
