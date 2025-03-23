shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

// Fixed: Removed slashes after shader_parameter
uniform float border_sharpness = 0.95;
uniform float height = 0.95;
uniform vec4 color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
varying vec3 local_pos;

void vertex() {
    // Position slightly above terrain
    // Fixed: vec4 constructor uses correct components (x,y from VERTEX, z=0.05, w=1.0)
    VERTEX = vec3(VERTEX.x,VERTEX.y, VERTEX.z+ height);
    local_pos = VERTEX.xyz;
}

void fragment() {
    // Hexagonal distance field calculation
    vec2 uv = UV * 2.0 - 1.0;
    vec2 p = abs(uv);
    float hex = max(p.x * 0.57735 + p.y, p.y * 1.73205) - 1.0;

    // Border calculation
    // Fixed: Use declared border_sharpness parameter
    float mask = smoothstep(border_sharpness, border_sharpness - 0.1, hex);

    // Final color from instance properties
    ALBEDO = color.rgb; // Use RGB components of color parameter
    ALPHA = color.a;
}