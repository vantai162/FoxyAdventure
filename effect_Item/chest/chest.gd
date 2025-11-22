extends InteractiveArea2D

@export var coin_reward: int = 0
@export var key_requirement: int = 1
var player: Player

var is_opened: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	interacted.connect(_on_interacted)
	animated_sprite.play("close")
	player = get_tree().get_first_node_in_group("player")
	
func _on_interacted():
	attempt_open_chest()

func attempt_open_chest():
	if is_opened:
		return
	if player.inventory.has_key():
		open_chest()

func open_chest():
	if is_opened:
		return
	is_opened = true
	player.inventory.use_key(key_requirement)
	animated_sprite.play("open")
	await animated_sprite.animation_finished
	player.inventory.adjust_amount_item("Coin",coin_reward)
	print("Chest opened! You received ", coin_reward, " coin!")
