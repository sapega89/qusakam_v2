shader_type canvas_item;

// Еліта (D560, DefaultEnemy._mark_elite): тонкий контур на прозорих пікселях поруч із фігурою, прозорість
// повільно дихає між alpha_min і alpha_max. Відтінок і прозорість спрайта (modulate) діють і на контур.

uniform vec4 outline_color : source_color = vec4(1.0, 0.81, 0.35, 1.0);
uniform float alpha_min = 0.45;
uniform float alpha_max = 0.85;
uniform float pulse_speed = 2.5;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	if (COLOR.a < 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float near = max(
			max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		float pulse = mix(alpha_min, alpha_max, 0.5 + 0.5 * sin(TIME * pulse_speed));
		COLOR = vec4(outline_color.rgb, step(0.5, near) * pulse * tint.a);
	}
}
