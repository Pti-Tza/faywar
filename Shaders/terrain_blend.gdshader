shader_type spatial;
render_mode blend_mix; // Fixed from blend_add

// Terrain blend parameters
uniform sampler2D base_albedo : source_color;
uniform sampler2D base_normal : hint_normal;

// Arrays for neighbor textures and directions
uniform int active_blend_count = 0;
uniform sampler2D blend_albedos[6] : source_color; // Neighbor albedo textures
uniform sampler2D blend_normals[6] ;  // Neighbor normal textures
uniform vec2 blend_directions[6]; // Direction vectors (xy: direction)

uniform float transition_distance = 1.0; // Transition smoothness
uniform float blend_width = 2.0;
uniform float blend_sharpness = 0.5;

varying vec3 world_position;

void vertex() {
    // Pass world position to fragment shader
    world_position = VERTEX;
}

void fragment() {
    // Base terrain values
    vec4 base_color = texture(base_albedo, UV);
    vec3 base_normal2 = texture(base_normal, UV).rgb * 2.0 - 1.0;
    
    vec3 blended_color = base_color.rgb;
    vec3 blended_normal = base_normal2;
    
    // Hex grid blending calculations
    for(int i = 0; i < active_blend_count; i++) {
        // Get direction to neighbor
        vec2 dir = normalize(blend_directions[i]);
        
        // Calculate edge position and distance
        vec2 edge_center = dir * transition_distance;
        float dist_to_edge = distance(world_position.xz, edge_center);
        
        // Calculate blend strength using smooth Hermite interpolation
        float blend_strength = 1.0 - smoothstep(
            transition_distance - blend_width,
            transition_distance + blend_width,
            dist_to_edge
        );
        
        // Only blend if within transition area
        if(blend_strength > 0.0) {
            vec4 neighbor_color = texture(blend_albedos[i], UV);
            vec3 neighbor_normal = texture(blend_normals[i], UV).rgb * 2.0 - 1.0;
            
            // Proper blending using premultiplied alpha
            blended_color = mix(blended_color, neighbor_color.rgb, blend_strength * neighbor_color.a);
            blended_normal = normalize(mix(blended_normal, neighbor_normal, blend_strength));
        }
    }
    
    // Final output
    ALBEDO = blended_color;
    NORMAL = blended_normal;
    ALPHA = base_color.a;
}