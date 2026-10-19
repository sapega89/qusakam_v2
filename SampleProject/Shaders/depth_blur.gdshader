shader_type canvas_item;

// Розмиття глибини (D233, «діорама» як в Octopath Traveler): дальні й ближні шари злегка розмиті,
// площина героя різка. Розмиває саму текстуру шару (3x3 вибірки на відстані radius текселів),
// без копії екрана — дешево для паралаксу. Прозорість теж розмивається, тож край силуету м'який.
// COLOR у fragment() уже помножений на текстуру, тож розмита текстура множиться лише на колір вершини
// (modulate шару): множення на COLOR підносило колір до квадрата — шари темніші й насиченіші (B67).
uniform float radius : hint_range(0.0, 4.0) = 1.0;
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 step = TEXTURE_PIXEL_SIZE * radius;
	vec4 sum = vec4(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			float w = (x == 0 && y == 0) ? 4.0 : ((x == 0 || y == 0) ? 2.0 : 1.0);
			sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * step) * w;
		}
	}
	COLOR = sum / 16.0 * modulate;
}
