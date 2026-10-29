shader_type canvas_item;

// Screen-space overlay: scanlines, rolling interference band, vignette and grain.
// Draw on a full-rect ColorRect with mouse_filter = IGNORE. WebGL2-safe.

uniform float scanline_alpha : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_density = 2.0;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.7;
uniform float band_alpha : hint_range(0.0, 1.0) = 0.035;
uniform float grain_alpha : hint_range(0.0, 1.0) = 0.03;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = FRAGCOORD.xy;
	float scan = step(0.5, fract(px.y / scanline_density)) * scanline_alpha;
	float band_pos = fract(TIME * 0.08);
	float band = smoothstep(0.06, 0.0, abs(SCREEN_UV.y - band_pos)) * band_alpha;
	vec2 c = SCREEN_UV - 0.5;
	float vig = clamp(dot(c, c) * vignette_strength * 1.6, 0.0, 1.0);
	float grain = (hash(px + fract(TIME) * 100.0) - 0.5) * grain_alpha;
	float a = clamp(scan + vig + abs(grain), 0.0, 1.0);
	COLOR = vec4(mix(tint.rgb, vec3(1.0), band / max(a + band, 0.001)), a + band);
}
