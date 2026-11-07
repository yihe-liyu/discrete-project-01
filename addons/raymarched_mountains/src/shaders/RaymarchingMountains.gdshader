shader_type spatial;
render_mode unshaded;

uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform float uv_scale = 0.1;
uniform float terrain_scale = 1.0;

varying vec3 world_camera;
varying vec3 world_position;

uniform int MAX_STEPS : hint_range(1, 256, 1) = 32;
uniform float MAX_DIST = 1000.0;

uniform vec3 terrain_color : source_color = vec3(0.5);
uniform vec3 shadow_color : source_color = vec3(0.0);
uniform sampler2D fogGradient : source_color;

uniform vec3 light_dir = vec3(1.0,1.0,-1.0);
uniform float fogStart;
uniform float fogEnd;

const float SURF_DIST = 1e-3;

// FAST, SAMPLER NOISE
float noise_sample(vec2 uv){
	return texture(noise, uv*0.01).r;
}


float GetDist(vec3 p) {
    return p.y - noise_sample(p.xz*uv_scale)*terrain_scale;
}

float RayMarch(vec3 ro, vec3 rd) {
    float dO = 0.0;
    float dS;

    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + dO * rd;
        dS = GetDist(p);
        dO += dS;

        if (dS < SURF_DIST || dO > MAX_DIST)
            break;
    }

    return dO;
}

vec3 GetNormal(vec3 p) {
    vec2 e = vec2(0.5, 0);

    vec3 n = GetDist(p) - vec3(
        GetDist(p - e.xyy),
        GetDist(p - e.yxy),
        GetDist(p - e.yyx)
    );

    return normalize(n);
}

void vertex() {
    world_position = VERTEX;
    world_camera = (inverse(MODELVIEW_MATRIX) * vec4(0, 0, 0, 1)).xyz;
}

float remap( float value, float originMin, float originMax, float destinationMin, float destinationMax) {
  return destinationMin +
  (value - originMin) * (destinationMax - destinationMin) / (originMax - originMin);
}

vec4 applyFog(vec3 color, float dist) {
    float fogFactor = (dist - fogStart) / (fogEnd - fogStart);
    fogFactor = clamp(fogFactor, 0.0, 1.0);
    vec4 fogColor = texture(
		fogGradient, vec2( remap(
			dist, fogStart, MAX_DIST,
			0.0, 1.0
		), 0.0)
	).rgba;

    return mix(vec4(color, 1.0), fogColor, fogFactor);
}

void fragment() {
    vec3 ro = world_camera;
    vec3 rd = normalize(world_position - ro);

    vec3 normal;

    float d = RayMarch(ro, rd);

    if (d >= MAX_DIST)
        discard;
    else {
        vec3 p = ro + rd * d;
        normal = GetNormal(p);
    }

    ALBEDO = mix(shadow_color,
		terrain_color,
		clamp(dot(normalize(normal), normalize(light_dir)), 0.0, 1.0));

	vec4 fog = applyFog(ALBEDO, d);
	ALBEDO = fog.rgb;
	ALPHA = fog.a;
}
