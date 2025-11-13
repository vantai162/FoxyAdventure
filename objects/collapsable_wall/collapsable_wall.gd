extends StaticBody2D
class_name BreakableWall

# --- Tải trước scene hiệu ứng ---
const DUST_EFFECT_SCENE = preload("res://objects/collapsable_wall/dust_effect.tscn")

# --- Lấy các node con ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox # Area2D con, KHÔNG phải HurtArea2D
@onready var break_sound: AudioStreamPlayer2D = $BreakSound
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_broken: bool = false

func _ready() -> void:
	# Kết nối tín hiệu "area_entered"
	print("DEBUG (Tường): Đã kết nối 'area_entered'.")

# Hàm này được gọi khi Hitbox phát hiện một Area2D khác
func _on_hitbox_area_entered(area: Area2D) -> void:
	print("DEBUG (Tường): Hitbox VỪA PHÁT HIỆN một Area2D! Tên là: ", area.name)
	
	# Kiểm tra đã vỡ chưa
	if is_broken:
		return
	
	# Kiểm tra xem Area2D va vào có phải là "đòn đánh" không
	if area.is_in_group("player_attack"):
		print("DEBUG (Tường): THÀNH CÔNG! Area này nằm trong group 'player_attack'.")
		break_wall()
	else:
		print("DEBUG (Tường): Area này KHÔNG nằm trong group 'player_attack'.")

# Hàm xử lý khi tường VỠ
func break_wall() -> void:
	# Ngăn chặn gọi nhiều lần
	if is_broken:
		return
	is_broken = true
	
	print("DEBUG (Tường): Đang chạy hàm break_wall()!")
	
	if break_sound:
		break_sound.play()
	
	# --- TẠO INSTANCE MỚI TỪ SCENE ---
	var dust_effect = DUST_EFFECT_SCENE.instantiate()
	# Thêm vào cây scene tại vị trí của tường
	get_parent().add_child(dust_effect)
	# Đặt vị trí hiệu ứng tại vị trí tường
	dust_effect.global_position = global_position
	# Gọi hàm play_effect (nếu có)
	if dust_effect.has_method("play_effect"):
		dust_effect.play_effect()
	
	# Vô hiệu hóa va chạm (kiểm tra null trước)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if hitbox:
		hitbox.set_deferred("monitoring", false) 
	
	# Ẩn sprite (kiểm tra null trước)
	if sprite:
		sprite.hide()
	
	# Chờ âm thanh phát xong rồi xóa tường
	if break_sound:
		await break_sound.finished
	queue_free()
