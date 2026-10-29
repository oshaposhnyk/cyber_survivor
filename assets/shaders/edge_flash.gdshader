shader_type canvas_item;

// Coloured screen-edge glow (damage / alert flash). Drive `intensity` from script.

uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.235, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 c = abs(SCREEN_UV - 0.5) * 2.0;
	float edge = pow(max(c.x, c.y), 5.0);
	COLOR = vec4(flash_color.rgb, edge * intensity);
}
