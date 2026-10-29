shader_type sky;
// Screen-space backdrop for an orthographic camera, whose sky would
// otherwise be one flat colour: a vertical gradient, with optional stars,
// ink-wash mountains and soft clouds. The cubemap pass
// feeds ambient light and reflections from a separate up/down gradient.
uniform vec3 top_color : source_color = vec3(0.6);
uniform vec3 bottom_color : source_color = vec3(0.8);
uniform float stars = 0.0;
uniform float mountains = 0.0;
uniform vec3 mountain_color : source_color = vec3(0.5);
uniform float clouds = 0.0;
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform vec3 light_top : source_color = vec3(0.6);
uniform vec3 light_bottom : source_color = vec3(0.3);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	return mix(hash(vec2(i, 0.0)), hash(vec2(i + 1.0, 0.0)), smoothstep(0.0, 1.0, fract(x)));
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float fbm2(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		value += amplitude * noise2(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

float fbm(float x) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		value += amplitude * noise(x);
		x *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		COLOR = mix(light_bottom, light_top, clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0));
	} else {
		vec2 uv = SCREEN_UV;
		vec3 color = mix(top_color, bottom_color, smoothstep(0.0, 1.0, uv.y));
		if (stars > 0.0) {
			vec2 grid = uv * vec2(170.0, 100.0);
			vec2 cell = floor(grid);
			vec2 offset = vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.7 + 0.15;
			float star = step(0.982, hash(cell)) * smoothstep(0.16, 0.0, length(fract(grid) - offset));
			color += vec3(star * (0.5 + hash(cell + 1.3))) * stars * (1.0 - smoothstep(0.3, 0.8, uv.y));
		}
		if (mountains > 0.0) {
			for (int layer = 0; layer < 2; layer++) {
				float depth = float(layer);
				float ridge = 0.40 + depth * 0.07 + 0.17 * fbm(uv.x * (2.6 + depth * 1.7) + depth * 13.0);
				float body = smoothstep(ridge - 0.003, ridge + 0.02, uv.y);
				float fade = 1.0 - smoothstep(ridge, ridge + 0.20 - depth * 0.06, uv.y);
				color = mix(color, mountain_color, body * fade * mountains * (0.45 + depth * 0.3));
			}
		}
		if (clouds > 0.0) {
			vec2 p = uv * vec2(3.2, 7.0);
			float cover = fbm2(p + vec2(fbm2(p * 0.6 + 2.0), fbm2(p * 0.6 + 5.0)) * 1.4);
			color = mix(color, cloud_color, smoothstep(0.5, 0.78, cover) * clouds * 0.75);
		}
		COLOR = color;
	}
}
