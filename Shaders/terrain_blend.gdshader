shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

// Terrain blend parameters
uniform sampler2D base_albedo : source_color;
uniform sampler2D base_normal : hint_normal;

// Arrays for neighbor textures and directions
uniform sampler2D blend_albedos[6] : source_color; // Neighbor albedo textures
uniform sampler2D blend_normals[6] ;  // Neighbor normal textures
uniform vec4 blend_directions[6]; // Direction vectors (xy: direction, zw: unused)

uniform float transition_distance = 1.0; // Transition smoothness

varying vec3 local_position;

void fragment() {
    // Get base terrain color and normals
    vec4 base_color = texture(base_albedo, UV);
    vec3 base_norm = texture(base_normal, UV).rgb * 2.0 - 1.0;

    // Blend with neighboring terrains
    vec3 final_color = base_color.rgb;
    vec3 final_norm = base_norm;

    for (int i = 0; i < blend_albedos.length(); i++) {
        // Skip empty textures (check if sampler is valid)


        // Extract direction vector from blend_directions
        vec2 dir = blend_directions[i].xy;
        float dist = length(local_position.xz - (dir * transition_distance));

        // Smooth transition based on distance
        float weight = smoothstep(transition_distance * 0.5, transition_distance, dist);
        weight = 1.0 - weight; // Reverse for proximity

        // Sample neighbor textures
        vec4 neighbor_color = texture(blend_albedos[i], UV);
        vec3 neighbor_norm = texture(blend_normals[i], UV).rgb * 2.0 - 1.0;

        // Blend colors and normals
        final_color = mix(final_color, neighbor_color.rgb, weight);
        final_norm = mix(final_norm, neighbor_norm, weight);
    }

    // Apply final values
    ALBEDO = final_color;
    NORMAL = final_norm;
}