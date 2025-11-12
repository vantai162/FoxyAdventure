extends Player_State

# Hàm _enter này lấy từ File 1, vì nó chi tiết và đúng logic hơn
func _enter() -> void:
	# 1. Dừng di chuyển và chạy animation "dead"
	obj.velocity = Vector2.ZERO

	obj.change_animation("dead")
	
	# 2. Đợi animation chết chạy xong (từ File 1, tốt hơn timer 2 giây)
	await obj.animated_sprite.animation_finished
	
	# 3. Đợi một chút cho kịch tính (từ File 1)
	await get_tree().create_timer(0.5).timeout
	
	# 4. Xử lý logic hồi sinh (từ File 1)
	if GameManager.has_checkpoint():
		await GameManager.respawn_at_checkpoint()
	else:
		# Hồi sinh tại chỗ (tải lại màn) nếu không có checkpoint
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
