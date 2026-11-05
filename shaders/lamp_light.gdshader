// The table under one weak bulb: near-black outside a soft pool of light over the play
// area, a little warmth inside it, and a slow, uneven breathing in the brightness, like
// a lamp on a failing line. Drawn over the table surface and under the cards and seats.
// dread (0 to 1) shrinks the pool and deepens the dark.
shader_type canvas_item;

uniform vec2 pool_center = vec2(0.41, 0.6);
uniform vec2 pool_radius = vec2(0.36, 0.42);
uniform float darkness : hint_range(0.0, 1.0) = 0.94;
uniform float softness : hint_range(0.05, 1.0) = 0.4;
uniform float breathe : hint_range(0.0, 0.2) = 0.05;
uniform float dread : hint_range(0.0, 1.0) = 0.0;
uniform vec3 warmth : source_color = vec3(0.35, 0.18, 0.04);

void fragment() {
	vec2 radius = pool_radius * (1.0 - dread * 0.25);
	float distance_out = length((UV - pool_center) / radius);
	float shadow = smoothstep(1.0 - softness, 1.0 + softness * 0.6, distance_out);
	// Two slow waves out of step, so the bulb never pulses evenly.
	float sway = sin(TIME * 0.7) * 0.6 + sin(TIME * 1.9 + 1.3) * 0.4;
	float dip = step(0.985, fract(sin(floor(TIME * 3.0)) * 43758.5)) * 0.5;
	float alpha = clamp(shadow * (darkness + dread * 0.1) + (sway + dip) * breathe, 0.0, 0.97);
	vec3 color = mix(warmth, vec3(0.0), smoothstep(0.0, 1.0, shadow));
	COLOR = vec4(color, alpha);
}
