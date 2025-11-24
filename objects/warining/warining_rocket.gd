extends Node2D

@onready var ani = $AnimatedSprite2D

@export var show_time: float = 1.0

func _ready():
	ani.visible = false

func show_animation():
	ani.visible = true
	ani.play("default") 
	await get_tree().create_timer(show_time).timeout
	ani.visible = false
