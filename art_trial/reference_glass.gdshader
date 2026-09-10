shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
// A thin silvered sheet reflects the studio, without a second game world.
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
float studio_card(vec3 origin, vec3 ray) {
 // A finite soft card gives the orthographic mirror subtle reflection parallax.
 if (abs(ray.z)<0.001) return 0.0;
 float distance=(-4.0-origin.z)/ray.z;
 if (distance<=0.0) return 0.0;
 vec2 point=(origin+ray*distance).xy-vec2(0.2,-2.0);
 vec2 edge=smoothstep(vec2(0.65,1.05),vec2(1.25,1.65),abs(point));
 return (1.0-edge.x)*(1.0-edge.y);
}
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p);
 f=f*f*(3.0-2.0*f);
 vec4 h=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453);
 return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}
void fragment() {
 vec2 position=UV*vec2(1.1,2.43);
 float cloud=noise(position*2.1)*0.7+noise(position*5.7)*0.3;
 float dx=noise(position*2.1+vec2(0.02,0))-noise(position*2.1-vec2(0.02,0));
 float dy=noise(position*2.1+vec2(0,0.02))-noise(position*2.1-vec2(0,0.02));
 NORMAL=normalize(NORMAL + TANGENT*dx*0.12 + BINORMAL*dy*0.12);
 float grazing=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.0);
 float edge_distance=min(min(position.x,1.1-position.x),min(position.y,2.43-position.y));
 float edge=1.0-smoothstep(0.0,0.035,edge_distance);
 ALBEDO=mix(vec3(0.44,0.55,0.59),vec3(0.69,0.76,0.78),cloud);
 vec3 world_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec3 reflected_ray=reflect(normalize(world_position-CAMERA_POSITION_WORLD),world_normal);
 float card=studio_card(world_position,reflected_ray);
 ALBEDO=mix(ALBEDO,vec3(0.81,0.87,0.90),card*0.5);
 EMISSION=vec3(0.11,0.13,0.15)*card;
 METALLIC=0.78;
 ROUGHNESS=0.16+cloud*0.06;
 SPECULAR=0.65;
 ALPHA=0.28+grazing*0.30+edge*0.10;
}
