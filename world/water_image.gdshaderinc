// The rule for the image of a thing in the pond's water, shared by every
// shader that the water's mirror camera draws (see `world/ice.gd`).
//
// The image is gone with height: it is strongest at the water and a thing
// more than `IMAGE_REACH` above the water leaves no shape there. So an image
// is never taken for ground. The image carries a small floor of brightness,
// because the water reads from its brightness how much of it is left
// (`world/ice.gdshader`).

const float IMAGE_REACH = 1.4;

// How much of the image is left at `lift` above the water.
float image_keep(float lift) {
	return pow(1.0 - clamp(lift / IMAGE_REACH, 0.0, 1.0), 1.6);
}

// The colour to write for a surface of colour `lit`, `lift` above the water.
vec3 image_colour(vec3 lit, float lift) {
	return (lit * 0.93 + 0.07) * image_keep(lift);
}
