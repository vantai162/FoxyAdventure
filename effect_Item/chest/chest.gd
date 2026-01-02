extends InteractiveArea2D
class_name Chest
## Base Chest - Exploration reward, opens freely by default
## Subclasses: GoldChest (locked), TrapChest (trickster)
##
## Design Philosophy:
## - Regular chests = "Thanks for exploring!" - no friction
## - Gold chests = "You earned this" - requires key investment
## - Trap chests = "Gotcha!" - trickster surprise (non-lethal)

@export_group("Locking")
@export var requires_key: bool = false  ## If true, needs a key to open
@export var required_key_id: String = ""  ## Match with Key's key_id. Empty = any key works
@export var keys_required: int = 1  ## How many keys needed (if requires_key)

@export_group("Reward")
@export var coin_reward: int = 5  ## Coins inside (default small reward)
@export var spawn_items: Array[PackedScene] = []  ## Items to spawn when opened

@export_group("Visual")
@export var shake_when_locked: bool = true  ## Shake feedback when trying without key

@export_group("Audio")
@export var open_sound: AudioStream
@export var locked_sound: AudioStream

var player: Player
var is_opened: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	super._ready()  # CRITICAL: Connect InteractiveArea2D signals (body_entered, body_exited)
	_chest_ready()


## Virtual setup - override in subclasses for custom initialization
func _chest_ready() -> void:
	interacted.connect(_on_interacted)
	if animated_sprite:
		animated_sprite.play("close")
	player = get_tree().get_first_node_in_group("player")


func _on_interacted() -> void:
	attempt_open_chest()


func attempt_open_chest() -> void:
	if is_opened:
		return
	
	if not player or not player.inventory:
		return
	
	# Check if key is required
	if requires_key:
		var has_key := _check_has_key()
		if has_key:
			open_chest()
		else:
			_on_locked()
	else:
		# No key needed - open freely!
		open_chest()


## Check if player has the required key
func _check_has_key() -> bool:
	if required_key_id.is_empty():
		# Any key works
		return player.inventory.has_key()
	else:
		# Specific key required - check inventory for Key_<id>
		var key_item_name := "Key_" + required_key_id
		if player.inventory.has_method("has_item"):
			return player.inventory.has_item(key_item_name, keys_required)
		else:
			return player.inventory.has_key()


## Consume keys from inventory
func _consume_keys() -> void:
	if not requires_key:
		return
	
	if required_key_id.is_empty():
		player.inventory.use_key(keys_required)
	else:
		var key_item_name := "Key_" + required_key_id
		if player.inventory.has_method("remove_item"):
			player.inventory.remove_item(key_item_name, keys_required)
		else:
			player.inventory.use_key(keys_required)


func open_chest() -> void:
	if is_opened:
		return
	
	is_opened = true
	
	# Consume key(s) if required
	_consume_keys()
	
	# Play open sound
	_play_sound(open_sound)
	
	# Satisfying chest opening burst!
	_spawn_open_burst()
	
	# Play animation
	if animated_sprite:
		animated_sprite.play("open")
		await animated_sprite.animation_finished
	
	# Give rewards (virtual - subclasses can override)
	_give_rewards()


## Spawn satisfying treasure burst on chest open
func _spawn_open_burst() -> void:
	var burst = GPUParticles2D.new()
	burst.amount = 16
	burst.lifetime = 0.7
	burst.explosiveness = 1.0
	burst.one_shot = true
	burst.z_index = 25
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(8, 2, 0)
	mat.direction = Vector3(0, -1, 0)  # Burst upward
	mat.spread = 45.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 90.0
	mat.gravity = Vector3(0, 80, 0)  # Fall back down (treasure weight)
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	mat.color = Color(1.0, 0.9, 0.3, 1.0)  # Gold treasure sparkle
	burst.process_material = mat
	
	# 4x4 treasure sparkle texture
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.8, 1.0))
	grad.set_color(1, Color(1.0, 0.85, 0.2, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 4
	tex.height = 4
	burst.texture = tex
	
	burst.global_position = global_position + Vector2(0, -8)  # Burst from lid
	get_tree().current_scene.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(burst):
			burst.queue_free()
	)


## Virtual reward method - override in subclasses for custom behavior
func _give_rewards() -> void:
	# Give coins
	if coin_reward > 0 and player and player.inventory:
		player.inventory.adjust_amount_item("Coin", coin_reward)
		AudioManager.play_sound("coin_spill",15.0)
	
	# Spawn items
	for item_scene in spawn_items:
		if item_scene:
			var item = item_scene.instantiate()
			item.global_position = global_position + Vector2(0, -16)
			get_parent().add_child(item)


func _on_locked() -> void:
	## Visual/audio feedback when trying to open without key
	AudioManager.play_sound("chest_lock",18.0)
	
	if shake_when_locked and animated_sprite:
		_shake_sprite()


func _shake_sprite() -> void:
	var orig_x := animated_sprite.position.x
	var tween := create_tween()
	tween.tween_property(animated_sprite, "position:x", orig_x + 3, 0.05)
	tween.tween_property(animated_sprite, "position:x", orig_x - 3, 0.05)
	tween.tween_property(animated_sprite, "position:x", orig_x + 2, 0.05)
	tween.tween_property(animated_sprite, "position:x", orig_x, 0.05)


## Utility to play a sound at this position
func _play_sound(stream: AudioStream) -> void:
	AudioManager.play_sound("chest_open",20.0)
