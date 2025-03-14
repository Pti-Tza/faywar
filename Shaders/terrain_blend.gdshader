// terrain_blend.gdshader
shader_type spatial;

uniform sampler2D base_albedo : hint_albedo;
uniform sampler2D base_normal : hint_normal;
uniform Array<vec3> blend_textures;
uniform float transition_distance;

void fragment() {
    vec2 base_uv = UV;
    vec4 albedo = texture(base_albedo, base_uv);
    vec3 normal = texture(base_normal, base_uv).rgb;
    
    for (int i = 0; i < blend_textures.length(); i++) {
        vec3 blend_info = blend_textures[i];
        vec2 blend_dir = normalize(blend_info.xy);
        float distance_factor = smoothstep(
            transition_distance * 0.8,
            transition_distance * 1.2,
            length(blend_info.xy)
        );
        
        vec4 blend_albedo = texture(blend_info.albedo, UV);
        vec3 blend_normal = texture(blend_info.normal, UV).rgb;
        
        albedo = mix(blend_albedo, albedo, distance_factor);
        normal = mix(blend_normal, normal, distance_factor);
    }
    
    ALBEDO = albedo.rgb;
    NORMAL_MAP = normal;
    METALLIC = 0.0;
    ROUGHNESS = 0.8;
}