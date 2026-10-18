shader_type canvas_item;
void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float edge = smoothstep(0.0, 0.13, UV.x) * (1.0 - smoothstep(0.78, 1.0, UV.x));
    edge *= smoothstep(0.0, 0.18, UV.y) * (1.0 - smoothstep(0.72, 1.0, UV.y));
    COLOR *= vec4(source.rgb, source.a * edge);
}
