shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float blur_amount : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;
	vec4 color = vec4(0.0);
	float total = 0.0;
	
	// Простий box blur
	float samples = blur_amount;
	
	for (float x = -samples; x <= samples; x += 1.0) {
		for (float y = -samples; y <= samples; y += 1.0) {
			vec2 offset = vec2(x, y) * pixel_size;
			color += texture(screen_texture, uv + offset);
			total += 1.0;
		}
	}
	
	COLOR = color / total;
}
