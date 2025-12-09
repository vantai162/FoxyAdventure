extends InteractiveArea2D
class_name Chest
## Chest that requires a key to open - Designer-friendly
## Set key_id to match a specific Key or leave empty for any key

@export_group("Locking")
@export var required_key_id: String = ""  ## Match with Key's key_id. Empty = any key works
@export var keys_required: int = 1  ## How many keys needed

@export_group("Reward")
@export var coin_reward: int = 0  ## Coins inside
@export var spawn_items: Array[PackedScene] = []  ## Items to spawn when opened

@export_group("Visual")
@export var shake_when_locked: bool = true  ## Shake feedback when trying without key

@export_group("Audio")
@export var open_sound: AudioStream
@export var locked_sound: AudioStream

var player: Player
var is_opened: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	interacted.connect(_on_interacted)
	if animated_sprite:
		animated_sprite.play("close")
	player = get_tree().get_first_node_in_group("player")
	
func _on_interacted():
	attempt_open_chest()

func attempt_open_chest():
	if is_opened:
		return
	
	if not player or not player.inventory:
		return
	
	# Check for required key
	var has_key = false
	if required_key_id.is_empty():
		# Any key works
		has_key = player.inventory.has_key()
	else:
		# Specific key required - check inventory for Key_<id>
		var key_item_name = "Key_" + required_key_id
		has_key = player.inventory.has_item(key_item_name, keys_required) if player.inventory.has_method("has_item") else player.inventory.has_key()
	
	if has_key:
		open_chest()
	else:
		_on_locked()

func open_chest():
	if is_opened:
		return
	
	is_opened = true
	
	# Consume key(s)
	if required_key_id.is_empty():
		player.inventory.use_key(keys_required)
	else:
		var key_item_name = "Key_" + required_key_id
		if player.inventory.has_method("remove_item"):
			player.inventory.remove_item(key_item_name, keys_required)
		else:
			player.inventory.use_key(keys_required)
	
	# Play open sound (could use AudioManager if sound_id mapping exists)
	if open_sound:
		var audio = AudioStreamPlayer2D.new()
		audio.stream = open_sound
		get_parent().add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
	
	# Play animation
	if animated_sprite:
		animated_sprite.play("open")
		await animated_sprite.animation_finished
	
	# Give coins
	if coin_reward > 0:
		player.inventory.adjust_amount_item("Coin", coin_reward)
	
	# Spawn items
	for item_scene in spawn_items:
		if item_scene:
			var item = item_scene.instantiate()
			item.global_position = global_position + Vector2(0, -16)
			get_parent().add_child(item)

func _on_locked():
	## Visual/audio feedback when trying to open without key
	if locked_sound:
		var audio = AudioStreamPlayer2D.new()
		audio.stream = locked_sound
		get_parent().add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
	
	if shake_when_locked and animated_sprite:
		var orig_x = animated_sprite.position.x
		var tween = create_tween()
		tween.tween_property(animated_sprite, "position:x", orig_x + 3, 0.05)
		tween.tween_property(animated_sprite, "position:x", orig_x - 3, 0.05)
		tween.tween_property(animated_sprite, "position:x", orig_x + 2, 0.05)
		tween.tween_property(animated_sprite, "position:x", orig_x, 0.05)
