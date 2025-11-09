extends EnemyState

func _enter() -> void:
	obj.change_animation("idle")
	obj.hide_shield()

func _update(_delta: float) -> void:
	# The parent object (shield_tribe.gd) handles the transition
	# to the defend state via Area2D signals.
	pass
