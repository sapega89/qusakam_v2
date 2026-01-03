shader_type canvas_item;

// Параметры эффекта энергетического луча
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform vec3 energy_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float time_offset : hint_range(0.0, 10.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	
	// Вычисляем расстояние от центра по вертикали
	float center_y = 0.5;
	float dist_from_center = abs(uv.y - center_y);
	
	// Прогресс по горизонтали (0.0 = начало, 1.0 = конец)
	float progress = uv.x;
	
	// Острый наконечник (первые 20%)
	float tip_alpha = 0.0;
	if (progress < 0.2) {
		float tip_progress = progress / 0.2;
		float tip_width = (1.0 - tip_progress) * 0.25 + 0.05;
		float dist_factor = dist_from_center / tip_width;
		if (dist_factor < 1.0) {
			tip_alpha = 1.0 - smoothstep(0.0, 1.0, dist_factor);
		}
	}
	
	// Основной след (20% - 80%)
	float beam_alpha = 0.0;
	if (progress >= 0.2 && progress < 0.8) {
		// Волновой эффект для энергии
		float wave = sin(uv.x * 20.0 + time_offset) * 0.02;
		float effective_center = center_y + wave;
		float dist_from_wave = abs(uv.y - effective_center);
		
		// Яркая центральная линия
		if (dist_from_wave < 0.06) {
			beam_alpha = 1.0 - smoothstep(0.0, 0.06, dist_from_wave);
		}
		// Среднее свечение
		else if (dist_from_wave < 0.15) {
			beam_alpha = 0.7 * (1.0 - smoothstep(0.06, 0.15, dist_from_wave));
		}
		// Внешнее свечение
		else if (dist_from_wave < 0.25) {
			beam_alpha = 0.3 * (1.0 - smoothstep(0.15, 0.25, dist_from_wave));
		}
	}
	
	// Хвост (последние 20%)
	float tail_alpha = 0.0;
	if (progress >= 0.8) {
		float tail_progress = (progress - 0.8) / 0.2;
		float tail_width = 0.15 + (1.0 - tail_progress) * 0.1;
		float dist_factor = dist_from_center / tail_width;
		if (dist_factor < 1.0) {
			tail_alpha = (1.0 - tail_progress) * (1.0 - smoothstep(0.0, 1.0, dist_factor));
		}
	}
	
	// Объединяем все части
	float final_alpha = max(max(tip_alpha, beam_alpha), tail_alpha);
	
	// Применяем свечение
	vec3 final_color = energy_color * (1.0 + glow_intensity * final_alpha);
	
	COLOR = vec4(final_color, final_alpha);
}

