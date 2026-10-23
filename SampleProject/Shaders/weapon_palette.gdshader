shader_type canvas_item;

// Палітрова заміна металу зброї в кадрах героя (BACKLOG 42): три ключові кольори меча (світлий, середній, темний)
// стають кольорами предмета в руці (Resources/Data/weapon_palettes.json, items.json → palette). Броню й око, що мали ті
// самі кольори, зсунуто з ключа (Scripts/Tools/weapon_key_fixups.py). Кристал ще мерехтить і світиться.
// Ставить WeaponView: active — лише поки грає анімація з кадрів зброї. Кольори без source_color: порівняння з кадром
// точне, без перетворення sRGB.

uniform bool active = false;
uniform vec3 key_light = vec3(0.973, 0.973, 0.894);
uniform vec3 key_mid = vec3(0.761, 0.761, 0.761);
uniform vec3 key_dark = vec3(0.529, 0.529, 0.549);
uniform vec3 to_light = vec3(0.973, 0.973, 0.894);
uniform vec3 to_mid = vec3(0.761, 0.761, 0.761);
uniform vec3 to_dark = vec3(0.529, 0.529, 0.549);
// Мерехтіння: смуга світла біжить уздовж металу (0 — немає).
uniform float shimmer : hint_range(0.0, 1.0) = 0.0;
// Сяйво: метал пульсує, а прозорі пікселі поруч із ним — ореол кольору glow_color (0 — немає).
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 glow_color = vec3(0.6, 0.95, 1.0);
// Білий спалах героя від удару по ньому (D581, VFXHooks.flash_hero): 0 — немає, 1 — кадр білий.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

// Один крок 8-бітного каналу: тіло зсунуте з ключа на 2 кроки.
const float TOLERANCE = 1.0 / 255.0;

int key_index(vec4 c) {
	if (c.a <= 0.0) {
		return -1;
	}
	if (all(lessThan(abs(c.rgb - key_light), vec3(TOLERANCE)))) {
		return 0;
	}
	if (all(lessThan(abs(c.rgb - key_mid), vec3(TOLERANCE)))) {
		return 1;
	}
	if (all(lessThan(abs(c.rgb - key_dark), vec3(TOLERANCE)))) {
		return 2;
	}
	return -1;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = c;
	if (active) {
		int k = key_index(c);
		if (k >= 0) {
			vec3 rgb = k == 0 ? to_light : (k == 1 ? to_mid : to_dark);
			float band = 0.5 + 0.5 * sin(TIME * 4.0 - (UV.x + UV.y) / TEXTURE_PIXEL_SIZE.x * 0.12);
			rgb += shimmer * pow(band, 6.0) * vec3(0.5);
			rgb += glow * (0.5 + 0.5 * sin(TIME * 2.5)) * 0.25 * glow_color;
			COLOR = vec4(min(rgb, vec3(1.0)), c.a);
		} else if (c.a <= 0.0 && glow > 0.0) {
			vec2 px = TEXTURE_PIXEL_SIZE;
			bool near = key_index(texture(TEXTURE, UV + vec2(px.x, 0.0))) >= 0
					|| key_index(texture(TEXTURE, UV - vec2(px.x, 0.0))) >= 0
					|| key_index(texture(TEXTURE, UV + vec2(0.0, px.y))) >= 0
					|| key_index(texture(TEXTURE, UV - vec2(0.0, px.y))) >= 0;
			if (near) {
				COLOR = vec4(glow_color, glow * (0.35 + 0.2 * sin(TIME * 2.5)));
			}
		}
	}
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash * step(0.001, c.a));
}
