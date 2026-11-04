// The one full-screen pass (P3B.7): pulls colors toward aged poster ink, adds print
// grain and a slight ink misregistration, darkens the edges, and flickers faintly.
// dread (0 to 1) desaturates, closes the vignette and strengthens the grain, so the
// board decays as the meters rise. It never moves or hides anything the player reads.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float grain : hint_range(0.0, 0.3) = 0.07;
uniform float misregistration : hint_range(0.0, 4.0) = 1.2;
uniform float vignette : hint_range(0.0, 1.5) = 0.55;
uniform float warmth : hint_range(0.0, 1.0) = 0.25;
uniform float flicker : hint_range(0.0, 0.1) = 0.015;
uniform float dread : hint_range(0.0, 1.0) = 0.0;
uniform vec3 paper_tint : source_color = vec3(0.94, 0.87, 0.72);

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE * misregistration;
	vec3 color;
	color.r = texture(screen, SCREEN_UV + vec2(pixel.x, 0.0)).r;
	color.g = texture(screen, SCREEN_UV).g;
	color.b = texture(screen, SCREEN_UV - vec2(0.0, pixel.y)).b;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, color * paper_tint * 1.08, warmth);
	color = mix(color, vec3(luma) * vec3(0.92, 0.9, 0.86), dread * 0.7);
	float noise = hash(floor(FRAGCOORD.xy / 2.0) + floor(TIME * 18.0)) - 0.5;
	color += noise * (grain + dread * 0.08);
	vec2 centered = SCREEN_UV - vec2(0.5);
	float edge = smoothstep(0.85 - dread * 0.3, 0.2, length(centered * vec2(1.0, 0.8)));
	color *= mix(1.0, edge, vignette + dread * 0.4);
	color *= 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 23.0) * sin(TIME * 7.0));
	COLOR = vec4(color, 1.0);
}
