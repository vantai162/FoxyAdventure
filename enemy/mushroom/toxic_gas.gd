extends Area2D

@export var velocity: Vector2
@export var lifetime := 2.0
@export var move_duration := 0.4
@export var fade_out_time := 1.0

var timer := 0.0
var moving := true
var fading := false
@onready var sprite := $Sprite2D

func _ready():
	scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), move_duration)

func _process(delta):
	# Hitstop: freeze in place when hit lands
	if HitstopManager.is_frozen(self):
		return
	
	timer += delta

	if moving:
		position += velocity * delta
		if timer >= move_duration:
			moving = false

	if timer >= lifetime - fade_out_time and not fading:
		fading = true
		_fade_out()

func _fade_out():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, fade_out_time)
	tween.tween_callback(queue_free)
