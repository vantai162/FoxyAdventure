extends Area2D
class_name Checkpoint


## Checkpoint that saves player progress when activated


#signal when checkpoint is activated
signal checkpoint_activated(checkpoint_id: String)


@export var checkpoint_id: String = ""


var is_activated: bool = false


func _ready() -> void:
	if checkpoint_id.is_empty():
		checkpoint_id = str(get_path())
	$AnimatedSprite2D.play("idle")
	if GameManager.current_checkpoint_id == checkpoint_id:
		activate_visual_only()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		activate()



func activate() -> void:
	print("ĐÃ CHẠM VÀ KÍCH HOẠT CHECKPOINT!")
	if is_activated:
		return
	is_activated = true
	$AnimatedSprite2D.play("active")

	GameManager.save_checkpoint(checkpoint_id)
	GameManager.save_checkpoint_data()
	checkpoint_activated.emit(checkpoint_id)
	await get_tree().create_timer(1.0).timeout

	$AnimatedSprite2D.play("idle")


#activate checkpoint visually without saving
func activate_visual_only() -> void:
	$AnimatedSprite2D.play("active")
	# No need to set is_activated here, as it's only visual
	
