shader_type canvas_item;

// D864: хмари на жовтому небі — кремові. Розмиття глибини як у depth_blur (radius, 0 — різко), а cream = 1
// перефарбовує хмару в дуотон cream_shade → cream_light за яскравістю (рожеві хмари та їхні фіолетові тіні);
// cream = 0 — як намальовано (синє небо після Лабораторії). Параметри задає SkyTint.gd з UITokens.
// Окремий шейдер, а не depth_blur: якість Low знімає depth_blur, а колір неба мусить лишитися (D554).
#include "res://SampleProject/Shaders/depth_blur.gdshaderinc"

uniform float radius : hint_range(0.0, 4.0) = 1.0;
uniform float cream : hint_range(0.0, 1.0) = 1.0;
uniform vec4 cream_light : source_color = vec4(1.0, 0.941, 0.8, 1.0);
uniform vec4 cream_shade : source_color = vec4(0.847, 0.737, 0.549, 1.0);
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 c;
	DEPTH_BLUR_SAMPLE(c, TEXTURE_PIXEL_SIZE * radius);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = mix(cream_shade.rgb, cream_light.rgb, smoothstep(0.45, 0.9, lum));
	COLOR = vec4(mix(c.rgb, tinted, cream), c.a) * modulate;
}
