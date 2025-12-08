extends EnemyState
## Elite Spawner Mushroom Run State
## Simple patrol when no player (transitions handled by main script)

@export var patrol_speed: float = 100.0

func _enter() -> void:
	obj.change_animation("run")

func _update(_delta):
	# Simple patrol
	obj.velocity.x = obj.direction * patrol_speed
	
	# Turn at obstacles
	if obj.is_touch_wall() or (obj.is_on_floor() and obj.is_can_fall()):
		obj.turn_around()
