#version 440
// Matrix rain, worked out per pixel on the GPU. Compile with:
//   /usr/lib/qt6/bin/qsb --qt6 -o MatrixRain.frag.qsb MatrixRain.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float tick;        // one tick = one row of fall
    vec2 resolution;   // pixels
    vec2 cellSize;     // one character cell, pixels
    float glyphCount;
};
layout(binding = 1) uniform sampler2D atlas;   // glyphs side by side, white on clear

// Dave Hoskins' hash12: no short cycles, so no two columns end up alike.
// Inputs are kept small so float precision never becomes a problem.
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 cellPos = qt_TexCoord0 * resolution / cellSize;
    vec2 cell = floor(cellPos);
    vec2 local = fract(cellPos);
    float col = cell.x;
    float row = cell.y;

    const float trail = 30.0;    // visible length of a drop, in rows
    const float maxGap = 16.0;   // longest random pause between drops
    float rows = ceil(resolution.y / cellSize.y);
    float period = rows + trail + maxGap;

    // Every column has its own start point and, on each pass, its own pause.
    float t = tick + floor(hash(vec2(col, 7.7)) * period);
    float pass = floor(t / period);
    float phase = t - pass * period;
    float gap = floor(hash(vec2(col, mod(pass, 500.0) + 13.1)) * maxGap);
    float age = (phase - gap) - row;   // rows behind the head of the drop

    if (age < 0.0 || age >= trail) {
        fragColor = vec4(0.0);
        return;
    }

    // The character in a cell is picked once per pass and then stays put.
    float g = min(floor(hash(vec2(col, row + mod(pass, 500.0) * 37.0)) * glyphCount), glyphCount - 1.0);
    float coverage = texture(atlas, vec2((g + clamp(local.x, 0.0, 0.999)) / glyphCount, local.y)).a;

    float a = coverage * exp2(age * log2(0.88));   // 12% dimmer per row behind the head
    vec3 color = age < 1.0 ? vec3(0.698, 0.400, 1.0) : vec3(0.608, 0.188, 1.0);
    fragColor = vec4(color * a, a) * qt_Opacity;
}
