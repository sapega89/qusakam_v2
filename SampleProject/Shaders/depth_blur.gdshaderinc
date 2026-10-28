// Розмиття глибини (D233): 3x3 вибірки текстури на відстані step. Спільне для depth_blur і sky_clouds (D864).
// Колір — з premultiplied суми: під прозорими пікселями PNG лежить колір квантизатора, і звичайне усереднення
// RGBA давало фіолетову облямівку на краях хмар, мез і скель (B68).
vec4 depth_blur_sample(sampler2D tex, vec2 uv, vec2 step) {
	vec4 sum = vec4(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			float w = (x == 0 && y == 0) ? 4.0 : ((x == 0 || y == 0) ? 2.0 : 1.0);
			vec4 t = texture(tex, uv + vec2(float(x), float(y)) * step);
			sum += vec4(t.rgb * t.a, t.a) * w;
		}
	}
	return vec4(sum.rgb / max(sum.a, 1e-4), sum.a / 16.0);
}
