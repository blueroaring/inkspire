shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float pressure = 0.0;
uniform float elapsed = 0.0;
uniform float release = -1.0;
uniform float power = 1.0;
uniform vec2 focus = vec2(0.62, 0.38);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float fog(vec2 p) {
	float v=0.0, a=0.5;
	for(int i=0;i<4;i++){v+=a*noise(p);p=mat2(vec2(1.6,1.2),vec2(-1.2,1.6))*p; a*=0.5;}
	return v;
}
void fragment() {
	float opacity=COLOR.a;
	vec2 uv=SCREEN_UV, d=(uv-focus)*vec2(1.77778,1.0);
	float r=length(d), angle=atan(d.y,d.x);
	float active=smoothstep(0.0,0.18,elapsed);
	float hit=release<0.0 ? 0.0 : exp(-release*5.0);
	float hold=release<0.0 ? 1.0 : exp(-release*2.7);
	float load=(0.35+pressure*0.65)*active*power*hold;
	// A screen-space dolly preserves the battle layout and restores exactly on deletion.
	vec2 sample_uv=focus+(uv-focus)/(1.0+load*0.065);
	sample_uv+=vec2(sin(elapsed*59.0),cos(elapsed*71.0))*hit*0.006*power;
	float warp=sin(r*35.0-elapsed*2.0)*load*0.002+hit*0.014*sin(r*24.0-release*20.0);
	sample_uv+=normalize(d+vec2(0.0001))*warp;
	vec2 fringe=normalize(d+vec2(0.001))*(0.001*load+0.004*hit);
	vec3 scene=vec3(texture(screen_tex,sample_uv+fringe).r,texture(screen_tex,sample_uv).g,texture(screen_tex,sample_uv-fringe).b);
	float grey=dot(scene,vec3(0.299,0.587,0.114));
	scene=mix(scene,vec3(grey)*vec3(0.60,0.63,0.91),load*0.75);
	float cloud=fog(d*4.2+vec2(elapsed*0.09,-elapsed*0.12));
	float rim=smoothstep(0.12,0.8,r);
	scene*=1.0-clamp(load*(0.38+rim*0.57+cloud*0.30),0.0,0.94);
	// Turbulent accretion disc and torn curtains, not a flat circle overlay.
	float edge=0.26+0.028*sin(angle*6.0+elapsed*0.3)+0.045*(cloud-0.5);
	float corona=exp(-abs(r-edge)*38.0)*(0.35+0.65*fog(vec2(angle*3.0,elapsed*0.5-r*8.0)));
	vec3 tint=mix(vec3(0.29,0.10,0.62),vec3(0.95,0.16,0.27),clamp(power-0.5,0.0,1.0));
	scene+=tint*corona*load*0.65;
	float curtain=pow(max(0.0,cloud*1.35-0.3),2.0)*rim;
	scene+=tint*curtain*load*0.17;
	// Impact is carried by the fissures and camera impulse, without exposure flashes.
	COLOR=vec4(scene,opacity);
}
