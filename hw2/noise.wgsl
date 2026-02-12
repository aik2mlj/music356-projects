#include FRAME_UNIFORMS
#include DRAW_UNIFORMS
#include STANDARD_VERTEX_INPUT
#include STANDARD_VERTEX_OUTPUT

@group(1) @binding(0) var<uniform> u_time : f32;
@group(1) @binding(1) var<uniform> u_color : vec3f;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    let UNUSED = u_time;
    var out: VertexOutput;
    var u_Draw: DrawUniforms = u_draw_instances[in.instance];
    let worldpos = u_Draw.model * vec4f(in.position, 1.0);
    out.position = (u_frame.projection * u_frame.view) * worldpos;
    out.v_worldpos = worldpos.xyz;
    out.v_normal = (u_Draw.model * vec4f(in.normal, 0.0)).xyz;
    out.v_uv = in.uv;
    return out;
}

// hash-based gradient noise (Perlin-style)
fn hash2(p: vec2f) -> vec2f {
    let k = vec2f(
        dot(p, vec2f(127.1, 311.7)),
        dot(p, vec2f(269.5, 183.3))
    );
    return fract(sin(k) * 43758.5453) * 2.0 - 1.0;
}

fn perlin(p: vec2f) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f); // smoothstep

    let g00 = dot(hash2(i + vec2f(0.0, 0.0)), f - vec2f(0.0, 0.0));
    let g10 = dot(hash2(i + vec2f(1.0, 0.0)), f - vec2f(1.0, 0.0));
    let g01 = dot(hash2(i + vec2f(0.0, 1.0)), f - vec2f(0.0, 1.0));
    let g11 = dot(hash2(i + vec2f(1.0, 1.0)), f - vec2f(1.0, 1.0));

    let mx0 = mix(g00, g10, u.x);
    let mx1 = mix(g01, g11, u.x);
    return mix(mx0, mx1, u.y);
}

fn fbm(p: vec2f) -> f32 {
    var val = 0.0;
    var amp = 0.5;
    var pos = p;
    for (var i = 0; i < 4; i++) {
        val += amp * perlin(pos);
        pos *= 2.0;
        amp *= 0.5;
    }
    return val;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    let UNUSED = u_frame;
    let uv = in.v_worldpos.xy * 6.0;
    let t = u_time * 0.5;

    // domain warping: fbm of fbm for a churning, organic look
    let warp = vec2f(
        fbm(uv + vec2f(t * 0.7, t * -0.3)),
        fbm(uv + vec2f(t * -0.4, t * 0.6))
    );
    let n = fbm(uv + warp * 3.0);

    // second warp layer for color variation
    let n2 = fbm(uv * 1.5 + warp * 2.0 + vec2f(t * 0.2, t * -0.5));

    // modulate noise around the base color with per-channel variation
    let intensity = smoothstep(-0.3, 0.6, n);
    let shift = vec3f(n2 * 0.3, n * n2 * -0.2, n2 * -0.15);
    let rgb = u_color * (0.3 + 0.7 * intensity) + shift;

    return vec4f(clamp(rgb, vec3f(0.0), vec3f(1.0)), 1.0);
}
