// terrain_blend.gdshader
shader_type spatial;
render_mode world_vertex_coords;

uniform sampler2DArray albedo_array : source_color, filter_linear_mipmap;
uniform sampler2DArray normal_array : hint_normal, filter_linear_mipmap;
uniform float texture_scale = 0.1;
uniform float blend_sharpness = 2.0;
uniform float normal_strength = 1.0;

varying flat vec2 texture_indices;

vec3 triplanar_blend(vec3 normal) {
    vec3 blending = pow(abs(normal), vec3(blend_sharpness));
    blending = normalize(max(blending, 0.00001));
    return blending / (blending.x + blending.y + blending.z);
}

void vertex() {
    // Get custom data containing texture indices
    texture_indices = vec2(CUSTOM0.r, CUSTOM0.g);
}

void fragment() {
    // Convert normalized values to 0-255 indices
    int albedo_index = int(texture_indices.x * 255.0);
    int normal_index = int(texture_indices.y * 255.0);

    // Calculate world position and normal
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 world_normal = normalize(NORMAL * mat3(MODEL_MATRIX));

    // Triplanar blending weights
    vec3 blending = triplanar_blend(world_normal);

    // Create proper UV coordinates with float casting
    vec3 uv_x = vec3(
        world_pos.zy * texture_scale,
        float(albedo_index)
    );
    vec3 uv_y = vec3(
        world_pos.xz * texture_scale,
        float(albedo_index)
    );
    vec3 uv_z = vec3(
        world_pos.xy * texture_scale,
        float(albedo_index)
    );

    // Sample textures using decoded indices
    vec4 albedo =
        texture(albedo_array, uv_x) * blending.x +
        texture(albedo_array, uv_y) * blending.y +
        texture(albedo_array, uv_z) * blending.z;

    // Sample normal maps
    vec3 normal =
        texture(normal_array, uv_x).rgb * blending.x +
        texture(normal_array, uv_y).rgb * blending.y +
        texture(normal_array, uv_z).rgb * blending.z;

    // Process normal maps
    normal = normalize(normal * 2.0 - 1.0);
    normal.xy *= normal_strength;

    // Set material properties
    ALBEDO = albedo.rgb;
    NORMAL_MAP = normal;
    ROUGHNESS = 1.0 - albedo.a;
    METALLIC = 0.0;
}