shader_type canvas_item;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Convert to grayscale
    float gray = dot(tex.rgb, vec3(0.333));

    // Darken heavily
    gray *= 0.5;

    COLOR = vec4(vec3(gray), tex.a);
}