extends Area2D
class_name Coin
## Collectible Coin - Designer-friendly with visual feedback
## Just place in scene, no code needed

@export_group("Reward")
@export var coin_value: int = 1  ## How many coins this gives

@export_group("Visual")
@export var float_animation: bool = true  ## Gentle floating motion
@export var float_amplitude: float = 3.0  ## How far up/down
@export var float_speed: float = 2.0
@export var sparkle_enabled: bool = true  ## Occasional sparkle effect

@export_group("Audio")
@export var collect_sound: AudioStream  ## Sound when collected

var _original_y: float
var _time: float = 0.0
var _collected: bool = false

func _ready() -> void:
	_original_y = position.y
	_time = randf() * TAU  # Random phase so coins don't sync
	
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default")

func _process(delta: float) -> void:
	if not float_animation or _collected:
		return
	
	_time += delta * float_speed
	position.y = _original_y + sin(_time) * float_amplitude

func _on_area_entered(area: Area2D) -> void:
	if _collected:
		return
	
	var player = area.get_parent()
	if not player.has_method("inventory") and not player.get("inventory"):
		# Try to find player in parent hierarchy
		player = area.get_parent()
	
	if player and player.has_node("inventory") or player.get("inventory"):
		_collected = true
		
		# Give coins
		player.inventory.adjust_amount_item("Coin", coin_value)
		
		# Play sound
		if collect_sound:
			var audio = AudioStreamPlayer2D.new()
			audio.stream = collect_sound
			audio.bus = "SFX"
			get_parent().add_child(audio)
			audio.play()
			audio.finished.connect(audio.queue_free)
		
		# Play collection animation
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("collected")
			await $AnimatedSprite2D.animation_finished
		
		queue_free()
