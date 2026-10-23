shader_type canvas_item;

// Журнал → картка персонажа (D486): пергамент темний, крім кола світла навколо місця зустрічі.
uniform vec2 center = vec2(0.5);       // центр світла, UV прямокутника
uniform float aspect = 1.0;            // ширина / висота прямокутника
uniform float radius = 0.22;           // частка висоти
uniform float softness = 0.3;
uniform vec4 shade_color : source_color = vec4(0.0, 0.0, 0.0, 0.94);

void fragment() {
	vec2 d = (UV - center) * vec2(aspect, 1.0);
	float dark = smoothstep(radius, radius + softness, length(d));
	COLOR = vec4(shade_color.rgb, shade_color.a * dark);
}
