#version 440
// Liquid glass for the Window Deck panel (shared with the launcher card).
//
// Samples a blurred snapshot of the screen behind the card. Inside a bezel
// band along the rounded edge the sample is bent toward the center like a
// convex lens (with a little chromatic dispersion), then the glass is tinted
// and lit by a specular rim. Compile with ./build.sh (qsb from qt6-shadertools).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;     // card size in item pixels (before the card's scale)
    vec4 screenRect;   // card rect on screen in pixels: x, y, w, h
    vec2 screenSize;   // size of the snapshot in pixels
    float radius;      // corner radius in item pixels
    float bezel;       // width of the lens band in item pixels
    float refraction;  // max displacement at the very edge, item pixels
    float dispersion;  // chromatic spread as a fraction of the displacement
    vec4 tint;         // rgb tint, a = strength
    float rim;         // specular rim strength
    float lift;        // overall brightness added to the glass
    float grain;       // film grain strength, gives the glass some body
    float sheen;       // soft light falling from the top edge
    float footerTop;   // item y where the darker footer band starts
    float footerShade; // how much the footer band darkens the glass
};

layout(binding = 1) uniform sampler2D source;

float sdRoundRect(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 sampleAt(vec2 screenPx) {
    return texture(source, clamp(screenPx / screenSize, vec2(0.0), vec2(1.0))).rgb;
}

void main() {
    vec2 halfSize = itemSize * 0.5;
    vec2 p = qt_TexCoord0 * itemSize - halfSize;
    float r = min(radius, min(halfSize.x, halfSize.y));
    float d = sdRoundRect(p, halfSize, r); // < 0 inside

    // Outward normal from the distance field gradient.
    const float e = 1.0;
    vec2 n = vec2(
        sdRoundRect(p + vec2(e, 0.0), halfSize, r) - sdRoundRect(p - vec2(e, 0.0), halfSize, r),
        sdRoundRect(p + vec2(0.0, e), halfSize, r) - sdRoundRect(p - vec2(0.0, e), halfSize, r));
    n = n / max(length(n), 1e-4);

    // Circular bevel profile: 0 in the flat middle, 1 right at the edge.
    float t = clamp(1.0 + d / bezel, 0.0, 1.0);
    float bend = 1.0 - sqrt(max(1.0 - t * t, 0.0));

    vec2 scale = screenRect.zw / itemSize;
    vec2 base = screenRect.xy + (p + halfSize) * scale;
    vec2 off = -n * bend * refraction * scale;

    vec3 col;
    col.r = sampleAt(base + off * (1.0 + dispersion)).r;
    col.g = sampleAt(base + off).g;
    col.b = sampleAt(base + off * (1.0 - dispersion)).b;

    col = mix(col, tint.rgb, tint.a) + lift;

    // Sheen: light falling in from the top, gone by mid card.
    float fromTop = p.y + halfSize.y;
    col += sheen * (1.0 - smoothstep(0.0, itemSize.y * 0.45, fromTop));

    // Footer band, clipped by the same rounded shape as the card.
    col = mix(col, vec3(0.0), footerShade * step(footerTop, fromTop));

    // Film grain, fixed to the screen so it does not crawl while animating.
    float noise = fract(sin(dot(floor(gl_FragCoord.xy), vec2(12.9898, 78.233))) * 43758.5453);
    col += (noise - 0.5) * grain;

    // Specular: a bright hairline where light (from the top left) hits the
    // rim, a softer one on the opposite side, and a faint glow down the bezel.
    vec2 lightDir = normalize(vec2(-0.55, -0.85));
    float facing = max(dot(n, lightDir), 0.0);
    float back = max(dot(n, -lightDir), 0.0);
    float hairline = smoothstep(2.2, 0.0, -d);
    col += rim * hairline * (0.85 * pow(facing, 1.5) + 0.35 * pow(back, 2.0) + 0.08);
    col += rim * 0.18 * bend * (0.7 * facing + 0.3);

    float alpha = clamp(0.5 - d, 0.0, 1.0); // antialiased edge
    fragColor = vec4(col, 1.0) * alpha * qt_Opacity;
}
