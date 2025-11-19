extends Node2D

@onready var animatedSprite2D: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	get_node("HitArea2D/CollisionShape2D").disabled = true
	get_node("HitArea2D2/CollisionShape2D").disabled = true
	play()
func play() -> void:
	while true:
		await start_phase()
		await active_phase()
		await end_phase()
func start_phase() -> void:
	animatedSprite2D.play("start")
	get_node("HitArea2D/CollisionShape2D").disabled = false
	await animatedSprite2D.animation_finished
func active_phase() -> void:
	animatedSprite2D.play("active")
	get_node("HitArea2D2/CollisionShape2D").disabled = false
	await animatedSprite2D.animation_finished
func end_phase() -> void:
	get_node("HitArea2D2/CollisionShape2D").disabled = true
	animatedSprite2D.play("end")
	get_node("HitArea2D/CollisionShape2D").disabled = true
	await animatedSprite2D.animation_finished
