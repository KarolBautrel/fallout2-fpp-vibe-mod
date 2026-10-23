shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;
varying vec3 world_tangent;
varying vec4 vertex_albedo;


float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 flat_normal = normalize(NORMAL);
	vec3 tangent = vec3(-flat_normal.z, 0.0, flat_normal.x);
	world_tangent = length(tangent) > 0.001
		? normalize(tangent)
		: vec3(1.0, 0.0, 0.0);
	vertex_albedo = COLOR;
}


void fragment() {
	const float block_width = 1.05;
	const float block_height = 0.38;
	const float mortar_size = 0.018;

	float row = floor(world_position.y / block_height);
	float horizontal = dot(world_position, normalize(world_tangent));
	float shifted_horizontal = horizontal + mod(row, 2.0) * block_width * 0.5;
	vec2 cell = vec2(
		fract(shifted_horizontal / block_width),
		fract(world_position.y / block_height)
	);
	float edge_x = min(cell.x, 1.0 - cell.x) * block_width;
	float edge_y = min(cell.y, 1.0 - cell.y) * block_height;
	float closest_edge = min(edge_x, edge_y);
	float antialias_width = max(fwidth(closest_edge) * 1.25, 0.002);
	float stone_mask = smoothstep(
		mortar_size - antialias_width,
		mortar_size + antialias_width,
		closest_edge
	);
	vec2 block_id = vec2(floor(shifted_horizontal / block_width), row);
	float variation = 0.86 + 0.14 * hash21(block_id);
	vec3 stone = vertex_albedo.rgb * variation;
	vec3 mortar = vertex_albedo.rgb * 0.58 + vec3(0.012, 0.009, 0.006);

	ALBEDO = mix(mortar, stone, stone_mask);
	ROUGHNESS = 0.96;
	SPECULAR = 0.18;
}
