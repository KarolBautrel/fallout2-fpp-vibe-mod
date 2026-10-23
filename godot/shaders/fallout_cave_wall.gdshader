shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;
varying vec4 vertex_albedo;


float hash31(vec3 value) {
	return fract(sin(dot(value, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_albedo = COLOR;
}


void fragment() {
	vec3 coarse_cell = floor(world_position * vec3(2.4, 3.2, 2.4));
	vec3 fine_cell = floor(world_position * vec3(8.0, 10.0, 8.0));
	float coarse = hash31(coarse_cell);
	float grain = hash31(fine_cell);
	float strata = step(0.82, fract(world_position.y * 2.7 + coarse * 0.41));
	float variation = 0.72 + coarse * 0.20 + grain * 0.10 - strata * 0.08;

	ALBEDO = vertex_albedo.rgb * variation;
	ROUGHNESS = 0.98;
	SPECULAR = 0.12;
}
