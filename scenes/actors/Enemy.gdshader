shader_type canvas_item;

// Bumped to 1.5 to guarantee all glitch artifacts clear off at the end
uniform float progress : hint_range(0.0, 2) = 2; 

uniform vec4 friendly_color : source_color = vec4(0.0, 1.0, 1.0, 1.0); // Cyan
uniform vec4 hostile_color : source_color = vec4(1, 0.0, 0.0, 1.0); // Red

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    // The normal, final color of your enemy (from the ColorRect/Polygon2D)
    vec4 base_color = COLOR; 
    
    vec2 blocky_uv = floor(UV * 20.0) / 20.0;
    float noise_val = random(blocky_uv);
    
    float visibility_threshold = 1.0 - progress;
    
    // THE DELAYED SHIFT: Squaring the progress keeps the color Cyan longer,
    // then aggressively shifts it to normal right at the end of the spawn.
    float color_shift_timing = clamp(pow(progress, 2.0), 0.0, 1.0);
    
    // We blend the Cyan with the enemy's TRUE base color for the solid body
    vec4 solid_body_color = mix(friendly_color, base_color, color_shift_timing);
    // We blend the Cyan with pure Red for the glitchy edge
    vec4 glitch_edge_color = mix(friendly_color, hostile_color, color_shift_timing);
    
    if (noise_val < visibility_threshold) {
        // Still invisible in the wall
        base_color.a = 0.0; 
    } else if (noise_val < visibility_threshold + 0.15) {
        // The bleeding glitch edge
        base_color = glitch_edge_color; 
    } else {
        // THE FIX: The solid part of the enemy ALSO gets the color shift!
        base_color = solid_body_color; 
    }
    
    COLOR = base_color;
}