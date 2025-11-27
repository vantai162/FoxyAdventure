extends Node

#target portal name is the name of the portal to which the player will be teleported
var target_portal_name: String = ""
# Checkpoint system variables
var current_checkpoint_id: String = ""
var checkpoint_data: Dictionary = {}
@onready var fade_rect = $FadeLayer/ColorRect
@export var player_scene: PackedScene
@onready var story_popup: CanvasLayer = $CanvasLayer/StoryPopup
var key_manager:KeyManager=KeyManager.new()
var current_stage = ""
var player: Player = null
var arriving_door_name: String = "" # New variable to signal arrival animation
var persistent_player_data: Dictionary = {}
var is_respawning_from_checkpoint: bool = false
var _pending_player_spawn_data: Dictionary = {}
var player_spawn_requested: bool = false
var player_spawn_data: Dictionary = {}
var paused=false

func _ready() -> void:
	load_checkpoint_data()
	key_manager._get_key_dictionary_from_input_map()
	current_checkpoint_id = ""
	checkpoint_data.clear()
	
	pass

#change stage by path and target portal name
func change_stage(stage_path: String, _target_portal_name: String = "") -> void:
	target_portal_name = _target_portal_name
	
	await fade_to_black()
	
	if is_instance_valid(player):
		save_player_state(player)
		player.queue_free()
		player = null
	
	get_tree().change_scene_to_file(stage_path)
	await get_tree().process_frame
	
	arriving_door_name = target_portal_name
	await fade_from_black()


func call_from_dialogic(msg:String = ""):
	pass

func save_player_state(p: Player) -> void:
	persistent_player_data = p.save_state()
	if persistent_player_data.has("position"):
		persistent_player_data.erase("position")





func save_checkpoint(checkpoint_id: String) -> void:
	if player == null:
		printerr("Cannot save checkpoint - player is null!")
		return
	
	current_checkpoint_id = checkpoint_id
	var player_state_dict: Dictionary = player.save_state()
	checkpoint_data[checkpoint_id] = {
		"player_state": player_state_dict,
		"stage_path": current_stage.scene_file_path
	}


func load_checkpoint(checkpoint_id: String) -> Dictionary:
	if checkpoint_id in checkpoint_data:
		return checkpoint_data[checkpoint_id]
	return {}

func respawn_at_checkpoint() -> void:
	is_respawning_from_checkpoint = true
	
	if current_checkpoint_id.is_empty():
		is_respawning_from_checkpoint = false
		return
	
	var checkpoint_info = checkpoint_data.get(current_checkpoint_id, {})
	if checkpoint_info.is_empty():
		is_respawning_from_checkpoint = false
		return
	
	var checkpoint_stage = checkpoint_info.get("stage_path", "")
	var player_state: Dictionary = checkpoint_info.get("player_state", {})
	
	# Inter-scene respawn
	if current_stage.scene_file_path != checkpoint_stage and not checkpoint_stage.is_empty():
		_pending_player_spawn_data = player_state
		await change_stage(checkpoint_stage, "")
		is_respawning_from_checkpoint = false
		return
	
	# Same-scene respawn
	await fade_to_black()
	
	# Delete player after screen is black
	if player != null:
		player.queue_free()
		player = null
	
	await get_tree().process_frame
	
	spawn_player(player_state)
	
	var hp_bar = current_stage.get_node("CanvasLayer/TextureProgressBar")
	var coin_ui = current_stage.get_node("CanvasLayer/CoinUI")
	var key_ui = current_stage.get_node("CanvasLayer/KeyUI")
	if current_stage.get_node("CanvasLayer/OxyBar"):
		var oxy_bar = current_stage.get_node("CanvasLayer/OxyBar")
		oxy_bar.setup()
	hp_bar.setup()
	coin_ui.setup()
	key_ui.setup()
	await fade_from_black()
	is_respawning_from_checkpoint = false

func has_checkpoint() -> bool:
	return not current_checkpoint_id.is_empty()

func save_checkpoint_data() -> void:
	var save_data = {
		"current_checkpoint_id": current_checkpoint_id,
		"checkpoint_data": checkpoint_data
	}
	SaveSystem.save_checkpoint_data(save_data)

func load_checkpoint_data() -> void:
	var save_data = SaveSystem.load_checkpoint_data()
	if not save_data.is_empty():
		current_checkpoint_id = save_data.get("current_checkpoint_id", "")
		checkpoint_data = save_data.get("checkpoint_data", {})

func clear_checkpoint_data() -> void:
	current_checkpoint_id = ""
	checkpoint_data.clear()
	SaveSystem.delete_save_file()

func fade_to_black(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration)
	await tween.finished


func fade_from_black(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)
	await tween.finished

func _collect_blade():
	if is_instance_valid(player):
		player._collected_blade()
	else:
		printerr("Dialogic called collect_blade but Player not found!")

func spawn_player(spawn_data: Dictionary) -> Player:
	if player_scene == null:
		printerr("Player scene not set in GameManager!")
		return null
	
	var new_player = player_scene.instantiate() as Player
	current_stage.add_child(new_player)
	
	new_player.load_state(spawn_data)
	
	if not spawn_data.has("health"):
		new_player.health = new_player.max_health
		
	
	new_player.velocity = Vector2.ZERO
	
	if not spawn_data.has("position"):
		var spawn_marker = current_stage.find_child("PlayerSpawn")
		if spawn_marker != null:
			new_player.global_position = spawn_marker.global_position
	
	if new_player.fsm and new_player.fsm.states:
		new_player.fsm.change_state(new_player.fsm.states.idle)
	else:
		printerr("Player FSM not initialized!")
	
	player = new_player
	return new_player

func request_player_spawn() -> void:
	if player_spawn_requested:
		return
	
	player_spawn_requested = true
	
	if not _pending_player_spawn_data.is_empty():
		player_spawn_data = _pending_player_spawn_data.duplicate()
		_pending_player_spawn_data.clear()
	elif not persistent_player_data.is_empty():
		player_spawn_data = persistent_player_data.duplicate()
		persistent_player_data.clear()
	else:
		player_spawn_data = {}
	
	spawn_player(player_spawn_data)
	player_spawn_requested = false
	player_spawn_data.clear()

func pause_game():
		Engine.time_scale=0
		paused=true
		
func unpause():
		Engine.time_scale=1
		paused=false
#handling key
func _input(event: InputEvent) -> void:
	if(key_manager.is_listening):
		key_manager.handle_input(event)
		
func show_story_popup(title: String, text: String) -> void:
	if story_popup == null:
		printerr("LỖI: Chưa gắn StoryPopup vào trong Scene của GameManager!")
		return
	
	# Gọi hàm open() mà bạn đã viết trong script StoryPopup.gd
	story_popup.open(title, text)
