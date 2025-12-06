extends Area2D
class_name HealthPotion
## Health pickup - Restores player health when collected
## Designer-friendly with visual and audio feedback

@export_group("Healing")
@export var heal_amount: int = 1  ## How much health to restore

@export_group("Visual")
@export var float_animation: bool = true
@export var float_amplitude: float = 3.0
@export var float_speed: float = 1.5
@export var glow_effect: bool = true

@export_group("Audio")
@export var pickup_sound: AudioStream  ## Override default sound

var _original_y: float
var _time: float = 0.0
var _collected: bool = false

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer if has_node("AudioStreamPlayer") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	_original_y = position.y
	_time = randf() * TAU
	
	if glow_effect and sprite:
		# Add subtle glow tween
		var tween = create_tween().set_loops()
		tween.tween_property(sprite, "modulate:a", 0.8, 0.5)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.5)

func _process(delta: float) -> void:
	if not float_animation or _collected:
		return
	
	_time += delta * float_speed
	position.y = _original_y + sin(_time) * float_amplitude

func _on_area_entered(area: Area2D) -> void:
	if _collected:
		return
	
	var player = area.get_parent()
	if not player or not player.has_method("checkfullhealth"):
		return
	
	# Don't collect if already at full health
	if player.checkfullhealth():
		return
	
	_collected = true
	
	# Hide immediately
	hide()
	
	# Heal player
	player.heal(heal_amount)
	
	# Play sound using AudioManager
	AudioManager.play_sound("heal", 20.0)
	
	# Brief delay for sound to play
	await get_tree().create_timer(0.3).timeout
	queue_free()
