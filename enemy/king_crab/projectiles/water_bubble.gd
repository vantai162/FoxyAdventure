extends RigidBody2D

@export var speed: float = 300.0
@export var life_time: float = 3.0
@export var trap_duration: float = 2.0
@export var grow_time: float = 1.0   

@onready var sprite = $AnimatedSprite2D

var trapped_player: Player = null
var trap_timer: float = 0
var launch_direction := Vector2.ZERO

func _ready():
	trap_timer = 0
	sprite.play("idle")
	scale = Vector2(0.2, 0.2)  
	_start_grow_effect()


func launch(direction: Vector2, bullet_speed: float):
	launch_direction = direction.normalized() * bullet_speed


func _start_grow_effect():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), grow_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	tween.finished.connect(_on_grow_finished)


func _on_grow_finished():
	linear_velocity = launch_direction


func _process(delta):
	if trap_timer > 0:
		trap_timer -= delta
		if trap_timer <= 0:
			explode()

	global_position += linear_velocity * delta

	if trapped_player:
		global_position = trapped_player.global_position

func _on_life_timer_timeout():
	explode()

func explode():
	sprite.play("explode")
	if trapped_player:
		trapped_player.Effect["BubbleTrap"] = 0
	await sprite.animation_finished
	queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	trap_timer = trap_duration
	trapped_player = body
	body.apply_bubble_trap(trap_duration)
	linear_velocity = Vector2.ZERO
