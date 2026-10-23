shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;
varying vec4 vertex_albedo;


float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_albedo = COLOR;
}


void fragment() {
	const vec2 slab_size = vec2(1.35, 0.92);
	const float joint_size = 0.010;
	vec2 slab_position = world_position.xz / slab_size;
	vec2 slab_cell = fract(slab_position);
	vec2 edge_distance = min(slab_cell, 1.0 - slab_cell) * slab_size;
	float closest_edge = min(edge_distance.x, edge_distance.y);
	float edge_width = max(fwidth(closest_edge) * 0.6, 0.001);
	float stone_mask = smoothstep(joint_size - edge_width, joint_size + edge_width, closest_edge);
	vec2 slab_id = floor(slab_position);
	float variation = 0.74 + hash21(slab_id) * 0.20;
	vec3 stone = vertex_albedo.rgb * variation;
	vec3 joint = vertex_albedo.rgb * 0.64;

	ALBEDO = mix(joint, stone, stone_mask);
	ROUGHNESS = 0.98;
	SPECULAR = 0.10;
}
