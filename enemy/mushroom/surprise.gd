extends EnemyState

@export var surprised_duration: float = 1.5 
var timer2: float = 0.0

func _enter() -> void:
	$"../../Direction/SleepIcon".visible = false
	$"../../Direction/AlertIcon".visible = true
	obj.change_animation("run")
	timer2 = surprised_duration
	obj.velocity = Vector2.ZERO  # đứng yên

func _update(delta):
	obj.velocity.x = 0
	timer2 -= delta
	if timer2 <= 0:
		change_state(fsm.states.run)
