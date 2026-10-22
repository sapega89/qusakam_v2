shader_type canvas_item;

// D428: яскравість екрана — гамма поверх усього, що вже намальовано у вʼюпорті (світ і UI).
// gamma 1.0 = без змін; > 1 світліше, < 1 темніше. Чорне лишається чорним, біле — білим.
uniform sampler2D screen: hint_screen_texture, filter_nearest;
uniform float gamma = 1.0;

void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 0.0).rgb;
	COLOR = vec4(pow(c, vec3(1.0 / gamma)), 1.0);
}
