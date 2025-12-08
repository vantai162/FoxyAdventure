extends Area2D
var is_collected: bool = false

func _ready() -> void:
	$AnimatedSprite2D.play("default")
	
func _on_area_entered(area: Area2D) -> void:
	if is_collected:
		return
	is_collected = true
	area.get_parent().inventory.adjust_amount_item("Coin",1)
	AudioManager.play_sound("coin_collected",15.0)
	$AnimatedSprite2D.play("collected")
	await $AnimatedSprite2D.animation_finished
	queue_free()
