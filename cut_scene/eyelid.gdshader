shader_type canvas_item;

// 0.0 = Nhắm tịt (Đen thui)
// 1.0 = Mở to (Thấy hết)
uniform float openness : hint_range(0.0, 1.0) = 0.0;

// Độ mờ viền (Làm cho tầm nhìn bị nhòe)
uniform float smoothness : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	// Tính khoảng cách từ tâm (0.5, 0.5)
	vec2 center = vec2(0.5, 0.5);
	
	// Biến đổi tỷ lệ để tạo hình bầu dục (Mắt người dẹt ngang)
	float dist = distance(UV * vec2(1.0, 0.5) + vec2(0.0, 0.25), center);
	
	// Tạo mặt nạ: Nếu nằm trong vùng mở thì trong suốt, ngoài thì màu đen
	// smoothstep giúp viền mềm mại, tạo cảm giác mắt đang mờ
	float mask = smoothstep(openness / 2.0, (openness / 2.0) - smoothness, abs(UV.y - 0.5));
	
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - mask);
}