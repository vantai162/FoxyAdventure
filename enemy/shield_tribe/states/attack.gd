extends EnemyState

@onready var spear_sprite: AnimatedSprite2D = $"../../Direction/Spear/AnimatedSprite2D"

func _enter() -> void:
	obj.change_animation("attack")
	obj.perform_spear_attack()
	
	# Show spear animation
	if spear_sprite:
		spear_sprite.visible = true
		spear_sprite.play("attack")
	
	var timer = get_tree().create_timer(obj.attack_animation_duration)
	timer.connect("timeout", Callable(self, "_on_animation_timer_finished"))

func _exit() -> void:
	# Hide spear after attack
	if spear_sprite:
		spear_sprite.visible = false

func _on_animation_timer_finished():
	if fsm.current_state == self:
		change_state(fsm.states.defend)

