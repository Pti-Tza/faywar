// terrain_blend.gdshader
shader_type spatial;

uniform sampler2DArray terrain_textures;
uniform float texture_scale = 1.0;
uniform float blend_sharpness = 2.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = VERTEX;
    world_normal = NORMAL;
}

void fragment() {
    // Triplanar mapping
    vec3 blending = abs(normalize(world_normal));
    blending = pow(blending, vec3(blend_sharpness));
    blending /= dot(blending, vec3(1.0));
    
    // Sample textures
    vec4 x_tex = texture(terrain_textures, vec3(world_pos.yz * texture_scale, 0));
    vec4 y_tex = texture(terrain_textures, vec3(world_pos.xz * texture_scale, 1));
    vec4 z_tex = texture(terrain_textures, vec3(world_pos.xy * texture_scale, 2));
    
    // Blend textures
    vec4 final_color = x_tex * blending.x + y_tex * blending.y + z_tex * blending.z;
    
    ALBEDO = final_color.rgb;
    NORMAL = world_normal;
}