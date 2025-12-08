shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.8, 0.0, 0.0, 1.0); // Màu đỏ
uniform float intensity : hint_range(0.0, 1.0) = 0.0; // Độ rõ

// Radius: Bán kính vùng an toàn. 
// Số càng NHỎ -> Vùng đỏ càng LẤN SÂU vào giữa.
uniform float radius : hint_range(0.0, 1.0) = 0.5; 
uniform float softness : hint_range(0.0, 1.0) = 0.4; // Độ mờ viền

void fragment() {
	float dist = distance(UV, vec2(0.5));
	// smoothstep giúp viền mờ dần ra rất tự nhiên
	float alpha = smoothstep(radius, radius + softness, dist);
	
	COLOR = color;
	COLOR.a = alpha * intensity;
}