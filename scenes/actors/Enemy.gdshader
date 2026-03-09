shader_type canvas_item;

// This is the slider we will animate from Godot (0.0 = fully glitched, 1.0 = solid)
uniform float progress : hint_range(0.0, 1.0) = 1.0; 

// The color of the malicious code
uniform vec4 corruption_color : source_color = vec4(0.9, 0.1, 0.1, 1.0); 

// A tiny math function to generate TV static/digital noise
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    // Get the base color of your Polygon/ColorRect
    vec4 base_color = COLOR; 
    
    // Create a blocky, pixelated grid for the UVs (adjust 20.0 for bigger/smaller blocks)
    vec2 blocky_uv = floor(UV * 20.0) / 20.0;
    float noise_val = random(blocky_uv);
    
    // Calculate the threshold
    float visibility_threshold = 1.0 - progress;
    
    if (noise_val < visibility_threshold) {
        // Pixel is still compressed in the wall (invisible)
        base_color.a = 0.0; 
    } else if (noise_val < visibility_threshold + 0.15) {
        // The bleeding edge of the glitch (bright red!)
        base_color = corruption_color; 
    }
    
    COLOR = base_color;
}