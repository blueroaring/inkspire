shader_type canvas_item;
uniform float hit_flash = 0.0;
uniform float pose_mix = 1.0;
uniform sampler2D previous_tex : filter_linear, repeat_disable;
uniform vec4 current_region = vec4(0.0,0.0,1.0,1.0);
uniform vec4 previous_region = vec4(0.0,0.0,1.0,1.0);
uniform vec2 current_size = vec2(512.0);
uniform vec2 previous_size = vec2(512.0);
uniform vec2 current_anchor = vec2(0.0);
uniform vec2 previous_anchor = vec2(0.0);
varying vec4 pose_tint;
void vertex() { pose_tint = COLOR; }
void fragment() {
	vec4 now=texture(TEXTURE,UV);
	if(pose_mix<1.0){
		vec2 local=(UV-current_region.xy)/current_region.zw*current_size+current_anchor;
		vec2 old_uv=(local-previous_anchor)/previous_size;
		vec4 old=texture(previous_tex,previous_region.xy+old_uv*previous_region.zw);
		if(any(lessThan(old_uv,vec2(0.0))) || any(greaterThan(old_uv,vec2(1.0)))) old=vec4(0.0);
		float a=mix(old.a,now.a,pose_mix);
		vec3 rgb=mix(old.rgb*old.a,now.rgb*now.a,pose_mix)/max(a,0.0001);
		now=vec4(rgb,a);
	}
	now*=pose_tint;
	COLOR=vec4(mix(now.rgb,vec3(1.0,0.93,0.79),hit_flash),now.a);
}
