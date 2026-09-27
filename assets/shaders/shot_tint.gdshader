shader_type canvas_item;
// Recolors a (blue) projectile from the reference sheet to the blaster's colour:
// brightness drives the tint, near-white cores stay white.

uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 c = COLOR;
	float v = max(c.r, max(c.g, c.b));
	float w = min(c.r, min(c.g, c.b));
	vec3 col = mix(tint.rgb * v * 1.2, vec3(1.0), smoothstep(0.55, 0.95, w));
	COLOR = vec4(col, c.a);
}
