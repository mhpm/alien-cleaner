---
name: godot-shader
description: Escribir shaders de Godot 4.x (.gdshader) para efectos 2D (destello al golpe, contorno, disolución, distorsión, mapa de degradado), materiales 3D, partículas y post-proceso de pantalla. Úsalo al crear o corregir un shader o un ShaderMaterial.
---

<!-- Copiado de github.com/alexmeckes/godot-claude-skills (881ff9d, licencia MIT, ver LICENSE.md). Corregidos para Godot 4: post-proceso (hint_screen_texture) y partículas. -->

**En este proyecto**: shaders en `assets/shaders/` (ej. `scenery_sway.gdshader`); el arte pixel usa filtro nearest (`texture_filter`, o `filter_nearest` en el sampler). Los efectos se ven en toda la horda: mantenerlos baratos (ver la skill `world-performance`).

# Godot Shader Skill

You are an expert at writing Godot 4.x shaders (.gdshader files) for 2D effects, 3D materials, and post-processing.

## Shader Types

```glsl
shader_type canvas_item;    // 2D sprites, UI, CanvasItem nodes
shader_type spatial;        // 3D materials
shader_type particles;      // GPU particle systems
shader_type sky;            // Sky/environment
shader_type fog;            // Volumetric fog
```

## Basic Shader Structure

```glsl
shader_type canvas_item;

// Render modes (optional)
render_mode unshaded, blend_mix;

// Uniforms (exposed to inspector)
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D noise_texture : hint_default_white;

// Varyings (pass data vertex -> fragment)
varying vec2 world_position;

void vertex() {
    // Modify vertex position
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    // Output color
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = tex_color * tint_color;
}
```

## Uniform Hints

```glsl
// Color picker in inspector
uniform vec4 color : source_color = vec4(1.0);

// Slider with range
uniform float value : hint_range(0.0, 1.0, 0.01) = 0.5;

// Texture hints
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D noise_tex : hint_default_white;
uniform sampler2D mask_tex : hint_default_black;

// Instance uniforms (per-instance values)
instance uniform vec4 instance_color : source_color = vec4(1.0);
```

## Built-in Variables

### Canvas Item (2D)
```glsl
// Vertex shader
VERTEX          // vec2 - vertex position
UV              // vec2 - texture coordinates
COLOR           // vec4 - vertex color
POINT_SIZE      // float - point size

// Fragment shader
UV              // vec2 - interpolated UVs
SCREEN_UV       // vec2 - screen space UVs
FRAGCOORD       // vec4 - fragment coordinates
COLOR           // vec4 - output color
NORMAL          // vec3 - normal for 2D lighting
TEXTURE         // sampler2D - sprite texture
TEXTURE_PIXEL_SIZE // vec2 - texel size

// Both
TIME            // float - shader time
PI              // float - 3.14159...
TAU             // float - 6.28318...
```

### Spatial (3D)
```glsl
// Vertex shader
VERTEX          // vec3 - vertex position (local)
NORMAL          // vec3 - vertex normal
UV              // vec2 - primary UVs
UV2             // vec2 - secondary UVs
COLOR           // vec4 - vertex color
POSITION        // vec4 - clip space position (output)

// Fragment shader
ALBEDO          // vec3 - base color (output)
ALPHA           // float - transparency (output)
METALLIC        // float - metalness (output)
ROUGHNESS       // float - roughness (output)
EMISSION        // vec3 - emissive color (output)
NORMAL_MAP      // vec3 - normal map (output)
NORMAL_MAP_DEPTH // float - normal map strength
AO              // float - ambient occlusion (output)
RIM             // float - rim lighting (output)
RIM_TINT        // float - rim tint amount
```

## Common 2D Shader Patterns

### Flash/Hit Effect
```glsl
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = mix(tex_color, flash_color, flash_amount);
    COLOR.a = tex_color.a;
}
```

### Outline
```glsl
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;

    float outline = texture(TEXTURE, UV + vec2(-size.x, 0)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
    outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
    outline = min(outline, 1.0);

    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = mix(outline_color * outline, tex_color, tex_color.a);
}
```

### Dissolve Effect
```glsl
shader_type canvas_item;

uniform sampler2D dissolve_texture : hint_default_white;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float noise = texture(dissolve_texture, UV).r;

    float edge = smoothstep(dissolve_amount, dissolve_amount + edge_width, noise);
    float alpha = step(dissolve_amount, noise);

    COLOR = mix(edge_color, tex_color, edge);
    COLOR.a = tex_color.a * alpha;
}
```

### Pixelate
```glsl
shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 100.0) = 4.0;

void fragment() {
    vec2 grid_uv = round(UV * pixel_size) / pixel_size;
    COLOR = texture(TEXTURE, grid_uv);
}
```

### Wave/Distortion
```glsl
shader_type canvas_item;

uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float wave_frequency : hint_range(0.0, 50.0) = 10.0;
uniform float wave_speed : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    vec2 uv = UV;
    uv.x += sin(uv.y * wave_frequency + TIME * wave_speed) * wave_amplitude;
    COLOR = texture(TEXTURE, uv);
}
```

### Gradient Map
```glsl
shader_type canvas_item;

uniform sampler2D gradient : hint_default_white;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float luminance = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 mapped = texture(gradient, vec2(luminance, 0.0)).rgb;
    COLOR = vec4(mapped, tex_color.a);
}
```

### Screen-Space Chromatic Aberration
```glsl
shader_type canvas_item;

uniform float offset : hint_range(0.0, 0.01) = 0.005;

void fragment() {
    vec2 dir = UV - vec2(0.5);
    float r = texture(TEXTURE, UV + dir * offset).r;
    float g = texture(TEXTURE, UV).g;
    float b = texture(TEXTURE, UV - dir * offset).b;
    float a = texture(TEXTURE, UV).a;
    COLOR = vec4(r, g, b, a);
}
```

## Common 3D Shader Patterns

### Basic PBR Override
```glsl
shader_type spatial;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 tex = texture(albedo_texture, UV);
    ALBEDO = tex.rgb * albedo_color.rgb;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    ALPHA = tex.a * albedo_color.a;
}
```

### Fresnel/Rim Lighting
```glsl
shader_type spatial;

uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim_power : hint_range(0.0, 10.0) = 3.0;

void fragment() {
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), rim_power);
    EMISSION = rim_color.rgb * fresnel * rim_color.a;
}
```

### Triplanar Mapping
```glsl
shader_type spatial;

uniform sampler2D texture_albedo : source_color;
uniform float blend_sharpness : hint_range(1.0, 10.0) = 3.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
    vec3 blending = pow(abs(world_normal), vec3(blend_sharpness));
    blending /= blending.x + blending.y + blending.z;

    vec3 x_proj = texture(texture_albedo, world_position.yz).rgb;
    vec3 y_proj = texture(texture_albedo, world_position.xz).rgb;
    vec3 z_proj = texture(texture_albedo, world_position.xy).rgb;

    ALBEDO = x_proj * blending.x + y_proj * blending.y + z_proj * blending.z;
}
```

### Hologram Effect
```glsl
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 hologram_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float scan_speed : hint_range(0.0, 10.0) = 2.0;
uniform float scan_line_count : hint_range(10.0, 200.0) = 50.0;
uniform float flicker_speed : hint_range(0.0, 20.0) = 5.0;

void fragment() {
    float scan = sin((UV.y + TIME * scan_speed) * scan_line_count) * 0.5 + 0.5;
    float flicker = sin(TIME * flicker_speed) * 0.1 + 0.9;
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 2.0);

    ALBEDO = hologram_color.rgb;
    EMISSION = hologram_color.rgb * (scan * 0.5 + 0.5) * flicker;
    ALPHA = (fresnel + 0.3) * scan * flicker * hologram_color.a;
}
```

## Post-Processing (Screen Shaders)

Apply to a ColorRect covering the viewport (on a CanvasLayer above the game). In Godot 4 `TEXTURE` there is the ColorRect's own white texture, NOT the screen: read the screen with a `hint_screen_texture` sampler and `SCREEN_UV`.

### Vignette
```glsl
shader_type canvas_item;

uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec4 color = texture(screen_texture, SCREEN_UV);

    float vignette = UV.x * UV.y * (1.0 - UV.x) * (1.0 - UV.y);
    vignette = clamp(pow(16.0 * vignette, vignette_intensity), 0.0, 1.0);

    color.rgb = mix(color.rgb, color.rgb * vignette, vignette_opacity);
    COLOR = color;
}
```

### CRT Effect
```glsl
shader_type canvas_item;

uniform float scanline_count : hint_range(0.0, 1000.0) = 400.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float curvature : hint_range(0.0, 0.1) = 0.02;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // Barrel distortion
    vec2 uv = SCREEN_UV - 0.5;
    float dist = dot(uv, uv);
    uv *= 1.0 + dist * curvature;
    uv += 0.5;

    vec4 color = texture(screen_texture, uv);

    // Scanlines
    float scanline = sin(uv.y * scanline_count * PI) * 0.5 + 0.5;
    color.rgb -= scanline_intensity * scanline;

    // Edge fade
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        color = vec4(0.0);
    }

    COLOR = color;
}
```

## Particle Shaders

There is no `RANDOM` built-in: hash `RANDOM_SEED` / `NUMBER`. `LIFETIME` is the total lifetime in seconds, not the progress; keep the 0..1 progress yourself (here in `CUSTOM.y`).

```glsl
shader_type particles;

uniform float spread : hint_range(0.0, 180.0) = 45.0;
uniform float initial_speed : hint_range(0.0, 100.0) = 10.0;

float rand(uint seed) {
    seed = (seed ^ 61u) ^ (seed >> 16u);
    seed *= 9u;
    seed = seed ^ (seed >> 4u);
    seed *= 0x27d4eb2du;
    seed = seed ^ (seed >> 15u);
    return float(seed % 10000u) / 10000.0;
}

void start() {
    if (RESTART_VELOCITY) {
        float angle = radians(spread) * (rand(RANDOM_SEED + NUMBER) - 0.5);
        VELOCITY = vec3(sin(angle), cos(angle), 0.0) * initial_speed;
    }
    CUSTOM.y = 0.0;
}

void process() {
    CUSTOM.y += DELTA / LIFETIME;          // progress 0..1
    float t = clamp(CUSTOM.y, 0.0, 1.0);
    VELOCITY.y -= 9.8 * DELTA;             // gravity
    COLOR.a = 1.0 - t;                     // fade out
    float k = 1.0 - t * 0.5;               // shrink
    TRANSFORM[0].xyz = normalize(TRANSFORM[0].xyz) * k;
    TRANSFORM[1].xyz = normalize(TRANSFORM[1].xyz) * k;
}
```

## Tips for AI Shader Generation

1. **Start simple** - Begin with basic structure, add complexity iteratively
2. **Use hints** - `hint_range`, `source_color` make shaders usable
3. **Comment uniforms** - Explain what each parameter does
4. **Provide defaults** - Always set sensible default values
5. **Consider performance** - Avoid expensive operations in fragment shader when possible
6. **Test edge cases** - UV boundaries, alpha handling, blend modes
7. **Match shader type to use case** - canvas_item for 2D, spatial for 3D
8. **Use built-ins** - TIME, UV, TEXTURE are optimized
