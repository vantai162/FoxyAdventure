shader_type canvas_item;

// Expanding ring shockwave - PRESSURE WAVE effect
// Works for: impact slams, roars, sonic booms
// Pure force visualization - white rings fading to nothing

uniform float ring_width : hint_range(0.01, 0.1) = 0.04;  // Slightly thicker for punch
uniform float expansion : hint_range(0.0, 1.0) = 0.0;  // 0 = center, 1 = fully expanded
uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // Pure white
uniform float fade_power : hint_range(0.5, 3.0) = 1.5;  // How fast rings fade (higher = faster)
uniform int ring_count : hint_range(1, 8) = 5;  // Concentric rings
uniform float ring_spacing : hint_range(0.08, 0.3) = 0.15;  // Spacing between rings

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv) * 2.0;  // 0 at center, 1 at edge
    
    float alpha = 0.0;
    
    // Create multiple rings - staggered expansion
    for (int i = 0; i < ring_count; i++) {
        float ring_offset = float(i) * ring_spacing;
        float ring_expansion = expansion - ring_offset;
        
        if (ring_expansion > 0.0 && ring_expansion < 1.0) {
            float ring_center = ring_expansion;
            float ring_dist = abs(dist - ring_center);
            
            // Ring shape with soft edges
            float ring_alpha = 1.0 - smoothstep(0.0, ring_width, ring_dist);
            
            // AGGRESSIVE fade as ring expands (force dissipates with distance)
            float expansion_fade = pow(1.0 - ring_expansion, fade_power);
            
            // First ring strongest, others fall off hard
            float ring_falloff = 1.0 / (1.0 + float(i) * 0.8);
            
            float this_alpha = ring_alpha * expansion_fade * ring_falloff;
            alpha = max(alpha, this_alpha);
        }
    }
    
    // Pure white, alpha-only fade
    COLOR = vec4(ring_color.rgb, ring_color.a * alpha);
}
