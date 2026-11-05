// The eyes in the dark beyond the lamp: an eyes-on-black texture added onto the
// darkness, fading slowly in and out, never moving. presence (0 to 1) sets how many you
// can make out; it rises with the meters but never quite reaches zero.
shader_type canvas_item;
render_mode blend_add;

uniform float presence : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 eyes = texture(TEXTURE, UV);
	float slow = 0.75 + 0.25 * sin(TIME * 0.35 + UV.x * 6.0);
	COLOR = vec4(eyes.rgb * presence * slow, 1.0);
}
