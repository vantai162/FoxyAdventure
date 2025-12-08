extends EnemyState
## Mini Mushroom Run State
## Dumb missile: Constant velocity in initial direction, no turning

func _enter() -> void:
	obj.change_animation("run")

func _update(_delta):
	# Move in locked direction at constant speed (no turning, no checks)
	obj.velocity.x = obj.initial_direction * obj.move_speed

