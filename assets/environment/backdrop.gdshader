shader_type sky;
// The backdrop for an orthographic camera, whose sky would otherwise be one
// flat colour: a vertical gradient across the screen, sky above and mist
// below. The cubemap pass feeds ambient light and reflections from its own
// gradient: cool from above (the blue of snow shadows), warm from the mist.
uniform vec3 top_color : source_color = vec3(0.6);
uniform vec3 bottom_color : source_color = vec3(0.8);
uniform vec3 light_top : source_color = vec3(0.6);
uniform vec3 light_bottom : source_color = vec3(0.3);

void sky() {
	if (AT_CUBEMAP_PASS) {
		COLOR = mix(light_bottom, light_top, smoothstep(-0.6, 0.8, EYEDIR.y));
	} else {
		COLOR = mix(top_color, bottom_color, smoothstep(0.05, 0.95, SCREEN_UV.y));
	}
}
