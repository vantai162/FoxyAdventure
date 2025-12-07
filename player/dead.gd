extends Player_State

func _enter() -> void:
	super._enter()
	obj.velocity = Vector2.ZERO
	obj.change_animation("dead")
	AudioManager.play_sound("game_over",15.0)
	await obj.animated_sprite.animation_finished
	await get_tree().create_timer(obj.dead_delay_before_respawn).timeout
	
	if GameManager.has_checkpoint():
		await GameManager.respawn_at_checkpoint()
	else:
		await respawn_at_default_position()
	


# Hàm này được giữ lại từ File 1
func respawn_at_default_position() -> void:
	# Làm mờ màn hình
	await GameManager.fade_to_black()
	
	# Reset trạng thái
	obj.health = obj.max_health
	obj.velocity = Vector2.ZERO
	
	# Tải lại màn chơi hiện tại
	get_tree().reload_current_scene()
	
	# (fade_from_black sẽ được gọi bởi hàm _ready() của stage)


# Hàm này lấy từ File 2 (RẤT QUAN TRỌNG)
# Bỏ qua mọi sát thương nhận vào khi player đã chết
func take_damage(_damage: int = 1) -> void:
	pass


# KHÔNG CẦN HÀM _update(delta)
# Vì chúng ta dùng 'await' thay vì 'timer'ad
	obj.change_animation("dead")
	obj.velocity.x = 0
	timer = 2


func _update(delta: float):
	if update_timer(delta):
		obj.get_tree().reload_current_scene()
