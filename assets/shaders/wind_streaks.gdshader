// Wind Streaks Shader - Horizontal wind visualization
// Creates flowing horizontal speed lines that indicate wind direction
shader_type canvas_item;

uniform float streak_count : hint_range(10.0, 200.0) = 80.0;
uniform float streak_length : hint_range(0.02, 0.5) = 0.15;
uniform float streak_thickness : hint_range(0.1, 2.0) = 0.8;
uniform vec4 streak_color : source_color = vec4(0.9, 0.95, 1.0, 0.4);
uniform float wind_speed : hint_range(0.1, 3.0) = 1.2;
uniform float turbulence : hint_range(0.0, 0.3) = 0.08;
uniform float direction_angle : hint_range(-3.14159, 3.14159) = 0.0; // radians, 0 = right, PI = left

// Noise function for organic variation
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float time = TIME * wind_speed;
	
	// Rotate UV based on wind direction
	// We rotate the coordinate space so that "wind direction" becomes +X
	float cos_a = cos(direction_angle);
	float sin_a = sin(direction_angle);
	vec2 rotated_uv = vec2(
		UV.x * cos_a + UV.y * sin_a,  // Note: changed sign for correct rotation
		-UV.x * sin_a + UV.y * cos_a
	);
	
	// Create streak grid
	float row = floor(rotated_uv.y * streak_count);
	float row_offset = hash(vec2(row, 0.0));
	
	// Add turbulence for organic movement
	float turb = noise(vec2(rotated_uv.y * 5.0, time * 0.5)) * turbulence;
	
	// Streak position with time offset
	// Streaks travel in the wind direction (positive X in rotated space)
	float streak_x = fract(rotated_uv.x - time + row_offset + turb);
	
	// Streak visibility (head to tail fade)
	float in_streak = smoothstep(0.0, streak_length, streak_x) * 
					  smoothstep(streak_length * 2.0, streak_length, streak_x);
	
	// Thickness based on row
	float row_fract = fract(rotated_uv.y * streak_count);
	float thickness_mask = smoothstep(0.5 - streak_thickness * 0.1, 0.5, row_fract) *
						   smoothstep(0.5 + streak_thickness * 0.1, 0.5, row_fract);
	
	// Random streak visibility (not all rows have streaks)
	float row_visible = step(0.4, hash(vec2(row, 1.0)));
	
	// Combine
	float alpha = in_streak * thickness_mask * row_visible * streak_color.a;
	
	// Vary streak brightness
	float brightness = 0.7 + 0.3 * hash(vec2(row, 2.0));
	
	COLOR = vec4(streak_color.rgb * brightness, alpha);
}
