shader_type canvas_item;
uniform float clock = 0.0;
uniform float reveal = 1.0;
uniform vec4 rim : source_color = vec4(0.65, 0.8, 1.0, 1.0);
void vertex() {
    // Very small secondary cloth drift. The authored face/hand silhouette stays stable.
    float cloth = smoothstep(0.48, 0.94, UV.y);
    VERTEX.x += sin(clock * 3.0 + UV.y * 9.0) * cloth * 3.0;
}
void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float sweep = exp(-pow((UV.x + UV.y * 0.2 - clock * 1.7 + 0.5) * 15.0, 2.0));
    source.rgb += rim.rgb * sweep * 0.22;
    source.a *= smoothstep(-0.06, 0.06, reveal * 1.3 - UV.x - UV.y * 0.2);
    source.a *= 1.0 - smoothstep(0.91, 0.985, UV.y);
    COLOR *= source;
}
