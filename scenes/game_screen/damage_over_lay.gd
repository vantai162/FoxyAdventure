extends Control

@onready var color_rect = $ColorRect
var shader_mat: ShaderMaterial

# --- CẤU HÌNH CHO 1 MÁU (NGUY KỊCH) ---
const HP1_INTENSITY = 0.85   # Rất đỏ
const HP1_RADIUS = 0.35      # Lấn sâu vào giữa màn hình
const HP1_SPEED = 6.0        # Thở dốc (Nhanh)

# --- CẤU HÌNH CHO 2 MÁU (CẢNH BÁO) ---
const HP2_INTENSITY = 0.55   # Đỏ vừa phải
const HP2_RADIUS = 0.45      # Chỉ đỏ ở viền ngoài
const HP2_SPEED = 2.5        # Thở chậm (Chậm)

# Biến để chuyển đổi mượt mà
var current_intensity_base = 0.0
var current_radius_base = 1.0
var current_speed = 0.0

func _ready():
	if color_rect.material:
		shader_mat = color_rect.material as ShaderMaterial
		shader_mat.set_shader_parameter("intensity", 0.0)

func _process(delta):
	var player = GameManager.player
	if not is_instance_valid(player): 
		if shader_mat: shader_mat.set_shader_parameter("intensity", 0.0)
		return

	# Lấy máu (Nhớ đổi thành player.health nếu code bạn dùng biến health)
	var hp = int(player.health)
	
	# --- 1. XÁC ĐỊNH MỤC TIÊU (TARGET) ---
	var target_intensity = 0.0
	var target_radius = 1.0
	var target_speed = 0.0
	

	if hp <= 1:
		target_intensity = HP1_INTENSITY
		target_radius = HP1_RADIUS
		target_speed = HP1_SPEED
		print("-> Đang kích hoạt Level 1 (Nguy kịch)") # Debug logic
	elif hp == 2:
		target_intensity = HP2_INTENSITY
		target_radius = HP2_RADIUS
		target_speed = HP2_SPEED
		print("-> Đang kích hoạt Level 2 (Cảnh báo)") # Debug logic

	else:
		# Máu đầy hoặc > 2 thì tắt
		target_intensity = 0.0
		target_radius = 1.0 # Đẩy viền ra khỏi màn hình
		target_speed = 0.0

	# --- 2. CHUYỂN ĐỔI MƯỢT MÀ (LERP) ---
	# Dùng lerp để thông số không bị "giật" khi chuyển từ 2 máu xuống 1 máu
	current_intensity_base = lerp(current_intensity_base, target_intensity, delta * 3)
	current_radius_base = lerp(current_radius_base, target_radius, delta * 3)
	current_speed = lerp(current_speed, target_speed, delta * 2)

	# --- 3. TẠO HIỆU ỨNG THỞ (BREATHING MATH) ---
	if current_intensity_base > 0.01:
		# Công thức sin tạo dao động từ -1 đến 1. 
		# Ta biến đổi nó thành dao động nhẹ (biên độ 0.1) để cộng vào Intensity
		var time = Time.get_ticks_msec() / 1000.0
		var breath = sin(time * current_speed) * 0.1 
		
		# Áp dụng vào Shader
		# Intensity = Gốc + Nhịp thở (Giữ cho nó không bị âm)
		var final_intensity = clamp(current_intensity_base + breath, 0.0, 1.0)
		
		shader_mat.set_shader_parameter("intensity", final_intensity)
		shader_mat.set_shader_parameter("radius", current_radius_base)
		shader_mat.set_shader_parameter("softness", 0.5) # Softness cố định cho đẹp
	else:
		shader_mat.set_shader_parameter("intensity", 0.0)
