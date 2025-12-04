extends Area2D

@export var coin_reward: int = 5
@export var key_requirement: int = 1


var is_opened: bool = false
var is_collision_with_player: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	animated_sprite.play("close")

	

func attempt_open_chest():
	if is_opened:
		return
	if GameManager.inventory.has_key():
		open_chest()

func open_chest():
	if is_opened:
		return
	is_opened = true
	GameManager.inventory.use_key(key_requirement)
	animated_sprite.play("open")
	await animated_sprite.animation_finished
	GameManager.inventory.adjust_amount_item("Coin",coin_reward)
	print("Chest opened! You received ", coin_reward, " coin!")


func _physics_process(delta: float) -> void:
	if is_collision_with_player and Input.is_action_just_pressed("interact"):
		attempt_open_chest()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		is_collision_with_player = true
		

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_collision_with_player = false
