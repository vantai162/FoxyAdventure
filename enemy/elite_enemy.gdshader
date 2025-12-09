shader_type canvas_item;

/// Elite Enemy Shader: "Chromatic Anomaly"
/// Creates a hue-shifted, high-contrast, energetic look
/// Philosophy: NOT gray mush - vivid alien color mutation with sharp details

// Hue rotation in degrees (180 = opposite color wheel side)
uniform float hue_shift : hint_range(0.0, 360.0) = 180.0;

// Saturation multiplier (>1 = more vivid, <1 = desaturated)
uniform float saturation : hint_range(0.0, 3.0) = 1.8;

// Contrast multiplier (>1 = sharper darks/lights)
uniform float contrast : hint_range(0.5, 3.0) = 1.6;

// Edge glow intensity (0 = none, 1 = strong rim light)
uniform float edge_glow : hint_range(0.0, 2.0) = 0.4;

// Glow color (default: cyan-white for alien feel)
uniform vec3 glow_color : source_color = vec3(0.6, 1.0, 1.0);

// RGB to HSV conversion
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    if (color.a >= 0.01) {
        // === 1. HUE ROTATION (color wheel shift) ===
        vec3 hsv = rgb2hsv(color.rgb);
        hsv.x += hue_shift / 360.0;  // Rotate hue
        hsv.x = fract(hsv.x);  // Wrap around 0-1

        // === 2. SATURATION BOOST (make colors MORE themselves) ===
        hsv.y *= saturation;
        hsv.y = clamp(hsv.y, 0.0, 1.0);

        // Convert back to RGB
        color.rgb = hsv2rgb(hsv);

        // === 3. CONTRAST ENHANCEMENT (sharpen details) ===
        // Push away from mid-gray (0.5) toward extremes
        color.rgb = ((color.rgb - 0.5) * contrast) + 0.5;

        // === 4. EDGE GLOW (rim lighting effect) ===
        if (edge_glow > 0.01) {
            // Detect edges by sampling neighbors (cheap edge detection)
            float edge_detect = 0.0;
            vec2 pixel_size = 1.0 / vec2(textureSize(TEXTURE, 0));

            // Sample 4 neighbors (cross pattern)
            edge_detect += texture(TEXTURE, UV + vec2(pixel_size.x, 0.0)).a;
            edge_detect += texture(TEXTURE, UV - vec2(pixel_size.x, 0.0)).a;
            edge_detect += texture(TEXTURE, UV + vec2(0.0, pixel_size.y)).a;
            edge_detect += texture(TEXTURE, UV - vec2(0.0, pixel_size.y)).a;

            // If center is opaque but neighbors are transparent = edge
            float is_edge = color.a * (4.0 - edge_detect);
            is_edge = clamp(is_edge, 0.0, 1.0);

            // Add glow to edges
            color.rgb += glow_color * edge_glow * is_edge;
        }

        // Clamp final color
        color.rgb = clamp(color.rgb, 0.0, 1.0);
    }

    COLOR = color;
}
