shader_type sky;
// Fixed studio illumination for material reflections; the visible background is separate.
void sky() {
	vec3 direction = normalize(EYEDIR);
	float upper = smoothstep(-0.35, 0.8, direction.y);
	vec3 base = mix(vec3(0.15, 0.13, 0.18), vec3(0.64, 0.62, 0.63), upper);
	float key = pow(max(dot(direction, normalize(vec3(-0.6, 0.75, 0.4))), 0.0), 18.0);
	float fill = pow(max(dot(direction, normalize(vec3(0.8, 0.3, -0.5))), 0.0), 12.0);
	COLOR = base + vec3(1.2, 1.08, 0.91) * key + vec3(0.48, 0.57, 0.7) * fill;
}
