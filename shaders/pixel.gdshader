// 픽셀 아트를 정수배가 아닌 배율로 키워도 도트 크기가 고르게 보이게 한다.
// 텍스처 필터는 선형으로 두고, 도트 경계 근처(화면 1픽셀 폭)만 섞는다.
shader_type canvas_item;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 p = UV * size;
	vec2 seam = floor(p + 0.5);
	vec2 d = max(fwidth(p), vec2(1e-5));
	p = seam + clamp((p - seam) / d, -0.5, 0.5);
	COLOR = texture(TEXTURE, p / size) * tint;
}
