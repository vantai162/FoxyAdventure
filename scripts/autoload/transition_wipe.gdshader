shader_type canvas_item;

// Transition progress: 0.0 = fully transparent, 1.0 = fully black
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// Wipe direction: 0=right, 1=left, 2=down, 3=up
uniform int direction : hint_range(0, 3) = 0;

// How soft the leading edge is (0.0 = hard, 0.3 = very soft)
uniform float feather : hint_range(0.0, 0.5) = 0.15;

// Subtle wave on the edge (0.0 = straight, 0.02 = gentle wave)
uniform float wave_amount : hint_range(0.0, 0.1) = 0.02;

// Wave frequency (how many waves across the edge)
uniform float wave_frequency : hint_range(1.0, 10.0) = 3.0;

void fragment() {
	vec2 uv = UV;
	float edge_pos;
	float wave_coord;
	
	// Determine the coordinate to use for the wipe based on direction
	// and calculate where the wave should sample from
	if (direction == 0) {
		// Right: wipe comes from right side, moving left
		edge_pos = 1.0 - uv.x;
		wave_coord = uv.y;
	} else if (direction == 1) {
		// Left: wipe comes from left side, moving right
		edge_pos = uv.x;
		wave_coord = uv.y;
	} else if (direction == 2) {
		// Down: wipe comes from bottom, moving up
		edge_pos = 1.0 - uv.y;
		wave_coord = uv.x;
	} else {
		// Up: wipe comes from top, moving down
		edge_pos = uv.y;
		wave_coord = uv.x;
	}
	
	// Add a subtle organic wave to the edge
	// Using sin for smooth wave, offset by progress so wave "moves" with wipe
	float wave = sin(wave_coord * wave_frequency * 6.28318 + progress * 2.0) * wave_amount;
	
	// The threshold moves from 0 to 1 as progress increases
	// When progress = 1.0, we want the screen FULLY COVERED (alpha = 1.0 everywhere)
	// When progress = 0.0, we want the screen FULLY TRANSPARENT (alpha = 0.0 everywhere)
	float threshold = progress * (1.0 + feather * 2.0);
	
	// Calculate alpha with soft feathered edge
	// smoothstep returns 0 when x < edge0, 1 when x > edge1
	// We want: high progress = high alpha (covered), low progress = low alpha (revealed)
	// edge_pos goes 0->1 across the screen in the wipe direction
	// When threshold is HIGH (progress=1), we want alpha=1 everywhere
	// When threshold is LOW (progress=0), we want alpha=0 everywhere
	float raw_alpha = smoothstep(threshold - feather, threshold, edge_pos + wave);
	
	// INVERT: smoothstep gives 0 when edge_pos is BELOW threshold (meaning covered)
	// But we want 1 (opaque) when covered, so invert
	float alpha = 1.0 - raw_alpha;
	
	// Output black with calculated alpha
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
