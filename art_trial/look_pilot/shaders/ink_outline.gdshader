shader_type spatial;
render_mode unshaded, cull_front;
// Inverted-hull ink line. Boxes grow from their centre, so corners stay
// closed; other meshes grow along their normals.
uniform float width = 0.022;
uniform vec3 ink : source_color = vec3(0.13, 0.13, 0.15);
uniform bool box = true;

void vertex() {
	VERTEX += box ? sign(VERTEX) * width : NORMAL * width;
}

void fragment() {
	ALBEDO = ink;
}
