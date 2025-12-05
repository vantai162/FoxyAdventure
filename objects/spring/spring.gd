extends Area2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D



func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemy"):
		animated_sprite.play("jump")
		body.spring()
		AudioManager.play_sound("power_up",20.0)


func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "jump":
		animated_sprite.play("idle")
