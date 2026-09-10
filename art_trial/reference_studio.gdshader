shader_type sky;
// Broad studio windows supply the glaze and silvering with soft reflections.
float window_light(vec3 direction, vec3 centre, vec3 up, vec2 size) {
 vec3 facing = normalize(centre);
 vec3 right = normalize(cross(up, facing));
 vec3 vertical = cross(facing, right);
 float depth = max(dot(direction, facing), 0.001);
 vec2 point = vec2(dot(direction, right), dot(direction, vertical)) / depth;
 vec2 edge = smoothstep(size, size + vec2(0.14), abs(point));
 return (1.0-edge.x)*(1.0-edge.y)*smoothstep(0.0,0.3,dot(direction,facing));
}
void sky() {
 vec3 direction = normalize(EYEDIR);
 float upper = smoothstep(-0.5,0.9,direction.y);
 vec3 room = mix(vec3(0.16,0.13,0.16), vec3(0.46,0.45,0.46), upper);
 float key = window_light(direction, vec3(-0.65,0.78,0.6), vec3(0,1,0), vec2(0.38,0.68));
 float fill = window_light(direction, vec3(0.8,0.4,-0.6), vec3(0,1,0), vec2(0.22,0.65));
 float lower_window = window_light(direction, vec3(-0.7,-0.3,-0.7), vec3(0,1,0), vec2(0.42,0.9));
 COLOR = room + vec3(0.48,0.45,0.40)*key + vec3(0.30,0.36,0.42)*fill + vec3(0.50,0.56,0.60)*lower_window;
 if (!AT_CUBEMAP_PASS) {
  float tone = smoothstep(-0.95,0.30,direction.y);
  COLOR = mix(vec3(0.25,0.19,0.22),vec3(0.40,0.30,0.32),tone);
 }
}
