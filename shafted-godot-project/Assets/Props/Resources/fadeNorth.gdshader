shader_type canvas_item;
 
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float fade_direction : hint_range(0.0, 3.0, 1.0) = 0.0;
// 0 = left  |  1 = right  |  2 = top  |  3 = bottom
 
void fragment() {
    float alpha;
    if (fade_direction < 0.5)       { alpha = 1.0 - UV.x; }
    else if (fade_direction < 1.5)  { alpha = UV.x; }
    else if (fade_direction < 2.5)  { alpha = 1.0 - UV.y; }
    else                            { alpha = UV.y; }
    alpha = smoothstep(0.0, 1.0, alpha);
    COLOR = vec4(fog_color.rgb, fog_color.a * alpha);
}