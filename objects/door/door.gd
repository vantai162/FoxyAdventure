extends Node2D

@export_file("*.tscn") var target_stage = ""
@export var target_door = "Door"
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.play("idle")
func load_next_stage() -> void:
		GameManager.change_stage(target_stage, target_door)

func _on_interactive_area_2d_interacted() -> void:
	var current_scene_path = get_tree().current_scene.scene_file_path
	var target_path = target_stage
	
	if target_stage.begins_with("uid://"):
		target_path = ResourceUID.get_id_path(ResourceUID.text_to_id(target_stage))
	
	print("current_scene_path: ", current_scene_path)
	print("target_path: ", target_path)
	
	if current_scene_path != target_path:
		load_next_stage()
	else:
		await GameManager.scene_transition.fade_out(0.3)
		GameManager.change_door(target_door)
		GameManager.respawn_at_portal()
		await get_tree().process_frame
		await GameManager.scene_transition.fade_in(0.3)
	#get_tree().change_scene_to_file("res://test/whirlpool_test.tscn")
	
	
func open_door() -> void:
	sprite.play("opening")

func close_door() -> void:
	sprite.play("closing")
	await sprite.animation_finished
	sprite.play("idle")

func _on_area_2d_body_entered(body: Node2D) -> void:
	open_door()
func _on_area_2d_body_exited(body: Node2D) -> void:
	close_door()
