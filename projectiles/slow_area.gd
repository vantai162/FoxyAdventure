extends Area2D
class_name SlowArea

@export var lifetime: float = 5.0
@export var fade_out_time: float = 1.0
@export var sprite_count: int = 8
@export var puddle_texture: Texture2D
@export var slow_duration: float = 3.0

var timer: float = 0.0
var sprites: Array[Sprite2D] = []
var fading: bool = false

func _ready() -> void:
	if not puddle_texture:
		return
		
	for i in range(sprite_count):
		var sprite = Sprite2D.new()
		sprite.texture = puddle_texture
		sprite.modulate = Color(0.4, 0.6, 1.0, 0.6)
		sprite.scale = Vector2(1.2, 1.2)
		
		var offset = Vector2(
			randf_range(-3, 3),
			randf_range(0, 6)
		)
		sprite.position = offset
		
		add_child(sprite)
		sprites.append(sprite)
		
		sprite.scale = Vector2(0.3, 0.3)
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.4 + randf_range(0, 0.2))
	
	_start_pulse_effect()

func _start_pulse_effect():
	for sprite in sprites:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.8), 0.5)
		tween.tween_property(sprite, "modulate", Color(0.4, 0.6, 1.0, 0.6), 0.5)

func _process(delta: float) -> void:
	timer += delta
	
	if timer >= lifetime - fade_out_time and not fading:
		_fade_out()
		fading = true
	
	if timer >= lifetime:
		queue_free()

func _fade_out():
	for sprite in sprites:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, fade_out_time)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("_applyeffect"): 
		body._applyeffect("Slow", slow_duration)
