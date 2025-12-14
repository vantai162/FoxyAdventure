shader_type canvas_item;

uniform float time_speed = 0.5;
uniform float darkness = 0.9;

void fragment() {
    vec2 uv = UV;

    float wave = sin((uv.x + TIME * time_speed) * 10.0) * 0.05;
    float alpha = smoothstep(0.1, 1.0, 1.0 - uv.x + wave) * darkness;

    COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
