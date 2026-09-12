shader_type sky;
// A quiet light field keeps glaze readable without bright studio windows.
void sky() {
 vec3 direction = normalize(EYEDIR);
 float upper = smoothstep(-0.5, 0.9, direction.y);
 vec3 room = mix(vec3(0.24, 0.22, 0.26), vec3(0.52, 0.51, 0.49), upper);
 float key = smoothstep(0.25, 0.95, dot(direction, normalize(vec3(-0.65, 0.78, 0.6))));
 COLOR = room + vec3(0.15, 0.14, 0.12) * key;
 if (!AT_CUBEMAP_PASS) {
  float tone = smoothstep(-0.95, 0.30, direction.y);
  COLOR = mix(vec3(0.25, 0.19, 0.22), vec3(0.40, 0.30, 0.32), tone);
 }
}
