extends EnemyState
@export var follow_move: float = 300.0
func _enter() -> void:
	obj.change_animation("run")

func _update(delta):
	if not  obj.is_player_in_sight():
		obj.velocity.x = obj.direction * obj.movement_speed
	else:
		obj.velocity.x = obj.direction * follow_move
	if _should_turn_around():
		obj.turn_around()

func _should_turn_around() -> bool:
	if obj.is_touch_wall():
		return true
	if obj.is_on_floor() and obj.is_can_fall():
		return true
	return false
