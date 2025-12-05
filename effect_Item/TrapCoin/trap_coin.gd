extends pick_up_item
class_name TrapCoin
## Fake coin that applies negative effect when collected
## Looks like a real coin but punishes greedy players!

## Inherited from pick_up_item:
## @export var effect_name: String  ## Effect to apply (e.g., "Stun", "Slow", "Poison")
## @export var duration: float  ## How long effect lasts

@export_group("Visual Disguise")
@export var looks_like_coin: bool = true  ## Use coin animation
@export var reveal_on_collect: bool = true  ## Flash red when triggered

@export_group("Audio")
@export var trap_sound: AudioStream  ## Evil sound when triggered

var _collected: bool = false

func _ready() -> void:
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default")

func _on_area_entered(area: Area2D) -> void:
	if _collected:
		return
	
	var player = area.get_parent()
	if not player or not player.has_method("_applyeffect"):
		return
	
	_collected = true
	
	# Apply trap effect
	player._applyeffect(effect_name, duration)
	
	# Visual feedback - flash red
	if reveal_on_collect and has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property($AnimatedSprite2D, "modulate:a", 0.0, 0.3)
	
	# Play trap sound
	if trap_sound:
		var audio = AudioStreamPlayer2D.new()
		audio.stream = trap_sound
		audio.bus = "SFX"
		get_parent().add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
	
	# Small delay before disappearing
	await get_tree().create_timer(0.3).timeout
	queue_free()
