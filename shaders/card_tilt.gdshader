// A soft sheen across a card that moves with its tilt toward the cursor. The tilt
// itself is a small rotation and lift from the motion system; this sells the light.
shader_type canvas_item;

// -1 to 1 on each axis: where the cursor is over the card.
uniform vec2 tilt = vec2(0.0);
uniform float sheen : hint_range(0.0, 1.0) = 0.16;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float light = clamp(dot(centered, -tilt) + 0.5, 0.0, 1.0);
	COLOR.rgb += sheen * light * clamp(length(tilt), 0.0, 1.0);
}
