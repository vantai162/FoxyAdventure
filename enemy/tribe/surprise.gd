extends EnemyState

@export var surprised_duration: float = 1.0 
var timer2: float = 0.0

func _enter() -> void:
	$"../../Direction/AlertIcon".visible = true
	obj.change_animation("surprise")
	timer2 = surprised_duration
	obj.velocity = Vector2.ZERO  # đứng yên

func _update(delta):
	timer2 -= delta
	if timer2 <= 0:
		$"../../Direction/AlertIcon".visible = false
		change_state(fsm.states.flee)
