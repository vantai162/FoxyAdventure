extends Camera2D

# --- CẤU HÌNH RUNG ---
var shake_decay: float = 5.0  

# Biến cho Rung thường (Quái đánh)
var shake_strength: float = 0.0

# Biến cho Rung xoay (Sóng thần/Cutscene)
var rot_strength: float = 0.0
var default_rotation: float = 0.0

func _ready():
	randomize()
	default_rotation = rotation

func _process(delta: float) -> void:
	# 1. Xử lý RUNG VỊ TRÍ (Offset)
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		offset = Vector2(
			randf_range(-1, 1),
			randf_range(-1, 1)
		) * shake_strength
	else:
		offset = Vector2.ZERO

	# 2. Xử lý RUNG XOAY (Rotation - Dành cho Cutscene)
	if rot_strength > 0:
		rot_strength = lerp(rot_strength, 0.0, shake_decay * delta)
		# Xoay ngẫu nhiên quanh trục
		rotation = default_rotation + randf_range(-rot_strength, rot_strength)
	else:
		# Trả về góc xoay gốc (giữ nguyên nếu đang bị Tween nghiêng)
		# Lưu ý: Nếu bạn đang dùng Tween để nghiêng camera, đoạn này có thể cần điều chỉnh
		# Nhưng với logic rung đơn thuần thì thế này là ổn.
		if rot_strength <= 0.01:
			rotation = default_rotation

# --- HÀM SET CAMERA LIMITS (Call từ Stage scripts) ---
func set_level_bounds(left: float = -10000000, right: float = 10000000, top: float = -10000000, bottom: float = 10000000) -> void:
	limit_left = int(left)
	limit_right = int(right)
	limit_top = int(top)
	limit_bottom = int(bottom)

# --- HÀM AUTO-DETECT BOUNDS TỪ TILEMAP (Optional helper) ---
func auto_detect_bounds_from_tilemap(tilemap: TileMapLayer, margin: Vector2 = Vector2(0, 0)) -> void:
	var used_rect = tilemap.get_used_rect()
	var tile_size = tilemap.tile_set.tile_size
	var map_pos = tilemap.global_position
	
	limit_left = int(map_pos.x + used_rect.position.x * tile_size.x - margin.x)
	limit_right = int(map_pos.x + used_rect.end.x * tile_size.x + margin.x)
	limit_top = int(map_pos.y + used_rect.position.y * tile_size.y - margin.y)
	limit_bottom = int(map_pos.y + used_rect.end.y * tile_size.y + margin.y)

# --- HÀM 1: DÙNG CHO QUÁI ĐÁNH (Giữ tên cũ để không phải sửa code Player) ---
func shake(amount: float = 10.0):
	shake_strength = amount
	# Khi bị đánh thì không cần rung xoay, set về 0 cho chắc
	rot_strength = 0.0 

# --- HÀM 2: DÙNG CHO CUTSCENE SÓNG THẦN ---
func shake_tsunami(amount: float = 30.0, rot_amount: float = 0.1):
	shake_strength = amount       # Rung vị trí cực mạnh
	rot_strength = rot_amount     # Rung xoay (0.1 radian ~ 5.7 độ)
