
extends Player_State

func _enter() -> void:
	obj.velocity = Vector2.ZERO
	obj.change_animation("water_trap")
	
func _update(delta: float) -> void:
	if obj.Effect["BubbleTrap"] <= 0:
		change_state(fsm.states.idle)
