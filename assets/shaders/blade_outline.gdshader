shader_type canvas_item;

// Blade Outline Shader - Per VISUAL_DESIGN_DOCTRINE.md
// "Every visual element must read as PIXELS, not blobs."
// This creates a crisp 1px outline for pixel-perfect contrast.

uniform vec4 outline_color : source_color = vec4(0.9, 0.95, 1.0, 1.0); // Cool white-blue
uniform float outline_width : hint_range(0.0, 2.0) = 1.0;
uniform bool enabled = true;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    if (!enabled) {
        COLOR = col;
        return;
    }
    
    // Only process if this pixel is transparent (we're looking for edges)
    if (col.a < 0.1) {
        // Check neighbors for opaque pixels
        vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
        
        float neighbor_alpha = 0.0;
        neighbor_alpha += texture(TEXTURE, UV + vec2(ps.x, 0.0)).a;
        neighbor_alpha += texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a;
        neighbor_alpha += texture(TEXTURE, UV + vec2(0.0, ps.y)).a;
        neighbor_alpha += texture(TEXTURE, UV + vec2(0.0, -ps.y)).a;
        
        // If any neighbor is opaque, this is an outline pixel
        if (neighbor_alpha > 0.1) {
            COLOR = outline_color;
        } else {
            COLOR = col;
        }
    } else {
        // Opaque pixel - keep original
        COLOR = col;
    }
}
