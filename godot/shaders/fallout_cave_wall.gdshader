shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;
varying vec4 vertex_albedo;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_albedo = COLOR;
}


void fragment() {
	float broad_rock = sin(world_position.x * 1.31 + world_position.z * 0.77);
	broad_rock += sin(world_position.z * 1.79 - world_position.y * 1.13) * 0.55;
	float fine_rock = sin((world_position.x - world_position.z) * 5.7) * 0.08;
	float strata = sin(world_position.y * 7.4 + broad_rock) * 0.045;
	float variation = 0.83 + broad_rock * 0.055 + fine_rock + strata;

	ALBEDO = vertex_albedo.rgb * variation;
	ROUGHNESS = 0.98;
	SPECULAR = 0.12;
}
