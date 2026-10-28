shader_type canvas_item;

// D864: жовте пилове небо до виходу з Лабораторії. Перефарбовує намальоване небо (текстура, градієнт чи колір
// Polygon2D) у дуотон sky_deep → sky_pale, зберігаючи його смуги: яскравіші й тепліші місця стають ближчими до
// обрію. yellow = 0 — небо як намальоване (синє, після Лабораторії). Параметри задає SkyTint.gd з UITokens.
uniform float yellow : hint_range(0.0, 1.0) = 1.0;
uniform vec4 sky_deep : source_color = vec4(0.788, 0.647, 0.369, 1.0);
uniform vec4 sky_pale : source_color = vec4(0.953, 0.886, 0.678, 1.0);

void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float height = smoothstep(0.3, 0.95, lum + (c.r - c.b) * 0.8);
	vec3 dust = mix(sky_deep.rgb, sky_pale.rgb, height);
	COLOR = vec4(mix(c.rgb, dust, yellow), c.a);
}
