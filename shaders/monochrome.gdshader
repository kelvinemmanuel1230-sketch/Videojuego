shader_type canvas_item;
render_mode blend_mix;

/// 0.0 = mundo sin color, 1.0 = colores originales restaurados.
uniform float saturation : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR *= texture(TEXTURE, UV);
	float gray = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(vec3(gray), COLOR.rgb, saturation);
}
