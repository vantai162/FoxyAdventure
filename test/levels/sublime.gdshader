shader_type canvas_item;

// Boosts color intensity without darkening
uniform float saturation : hint_range(1.0, 2.5) = 1.6;

// Lifts shadows/mids to remove that dusty medieval feel
uniform float brightness_lift : hint_range(0.0, 0.3) = 0.15;

// Reduces yellow/warm cast, keeps colors true
uniform float warmth_reduction : hint_range(0.0, 0.2) = 0.08;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // Lift darker tones to remove muddiness (keeps lights unchanged)
    float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    color.rgb += brightness_lift * (1.0 - luminance); // Only affects darker areas
    
    // Boost saturation (makes colors "more themselves")
    vec3 gray = vec3(dot(color.rgb, vec3(0.299, 0.587, 0.114)));
    color.rgb = mix(gray, color.rgb, saturation);
    
    // Reduce yellow warmth without killing browns/oranges
    color.r -= warmth_reduction * 0.5; // Gentle red reduction
    color.b += warmth_reduction;        // Slight blue boost for coolness
    
    COLOR = color;
} 