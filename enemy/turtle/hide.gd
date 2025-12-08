extends EnemyState
## Base Turtle Hide State
## Invulnerable shell retreat - used reactively (when hurt) and proactively (periodic)

@export var hide_duration: float = 3.0  ## Base: Longer than elite (3.0s vs 2.5s)

var hide_timer := 0.0

func _enter():
	obj.change_animation("hide")
	obj.velocity = Vector2.ZERO
	hide_timer = 0.0
	if obj.has_node("Direction/HurtArea2D"):
		var hurt_area = obj.get_node("Direction/HurtArea2D")
		hurt_area.set_deferred("monitoring", false)
		hurt_area.set_deferred("monitorable", false)
		
func _update(delta: float) -> void:
	hide_timer += delta
	if hide_timer >= hide_duration:
		change_state(fsm.default_state)

func _exit() -> void:
	if obj.has_node("Direction/HurtArea2D"):
		var hurt_area = obj.get_node("Direction/HurtArea2D")
		hurt_area.set_deferred("monitoring", true)
		hurt_area.set_deferred("monitorable", true)
