extends Node2D
## DEPRECATED: Use FlameHazard instead for new levels
## This is the legacy flame without light emission
## FlameHazard (flame_hazard.gd) includes:
##   - Light emission (PointLight2D)
##   - Configurable on/off durations
##   - Cycle enable/disable option
##   - Ignite/extinguish methods for puzzles

@onready var animatedSprite2D: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	push_warning("Flame: Consider using FlameHazard for new levels (includes light)")
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
