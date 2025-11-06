extends RigidBody2D

@export var lifetime: float = 2.0
@export var velocity: Vector2 = Vector2.ZERO
@export var move_duration: float = 0.4
@export var fade_out_time: float = 1.0

var timer: float = 0.0
var sprite: Sprite2D
var moving: bool = true
var fading: bool = false
func _ready() -> void:
	sprite = $Sprite2D
	self.scale = Vector2(0.5,0.5)
	var tween = create_tween()
	tween.tween_property(sprite,"scale",Vector2(1.2,1.2),move_duration)
	
func _process(delta: float) -> void:
	timer += delta
	if moving:
		position += velocity*delta
		if timer >= move_duration:
			moving=false
			velocity=Vector2.ZERO
	if timer >= lifetime - fade_out_time and not fading:
		_fade_out()
		fading = true
func _fade_out():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, fade_out_time)
	tween.tween_callback(queue_free)  
