shader_type canvas_item;
render_mode blend_add;

uniform vec4  glow_color  : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform vec4  core_color  : source_color = vec4(1.0,  1.0,  1.0, 1.0);
uniform float flicker_amp : hint_range(0.0, 1.0) = 0.20;

void fragment() {
	// UV.y runs 0→1 across the line width; 0.5 is the center.
	float d    = abs(UV.y - 0.5) * 2.0;          // 0 at center, 1 at edges
	float glow = 1.0 - smoothstep(0.0, 1.0, d);  // soft envelope
	float core = 1.0 - smoothstep(0.0, 0.28, d); // tight bright core

	// TIME is a Godot built-in — updates every frame without a CPU uniform.
	// UV.x varies 0→1 along the length, giving spatially varied flicker.
	float flicker = 1.0 + flicker_amp * sin(TIME * 63.7 + UV.x * 9.3);

	vec4 col = mix(glow_color, core_color, core);
	col.rgb  *= flicker;
	// COLOR.a carries the Line2D modulate alpha (used for fade-out).
	col.a     = glow * COLOR.a;

	COLOR = col;
}
