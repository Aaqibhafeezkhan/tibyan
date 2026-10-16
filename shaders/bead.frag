#version 460 core

// One misbaha bead as a lit sphere (the «ثلاثي الأبعاد حقيقي» rendering):
// the normal is rebuilt per pixel from the sphere's screen disc, and lit
// with Lambert diffuse, Blinn-Phong specular, a rim and, for amber and
// pearl, light scattered through the bead.

#include <flutter/runtime_effect.glsl>

uniform vec2 uCenter;
uniform float uRadius;
uniform vec3 uLight;
uniform vec3 uColor;
uniform float uSpec;
uniform float uScatter;
uniform float uFade;

out vec4 fragColor;

void main() {
  vec2 p = (FlutterFragCoord().xy - uCenter) / uRadius;
  float d = length(p);
  if (d > 1.0) {
    fragColor = vec4(0.0);
    return;
  }
  vec3 n = vec3(p.x, p.y, sqrt(max(0.0, 1.0 - d * d)));
  vec3 l = normalize(uLight);
  float diff = max(dot(n, l), 0.0);
  vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
  float spec = pow(max(dot(n, h), 0.0), 56.0) * uSpec;
  float rim = pow(1.0 - n.z, 3.0);
  // Light entering the far side and leaving toward the eye.
  float through = uScatter * pow(max(dot(-n, l), 0.0), 1.5) * 0.6 +
      uScatter * 0.35 * (1.0 - diff) * n.z;
  vec3 c = uColor * (0.18 + 0.82 * diff) + uColor * through +
      vec3(spec) + uColor * rim * 0.18;
  c = mix(c, c * 0.5, uFade);
  float a = clamp((1.0 - d) * uRadius * 1.2, 0.0, 1.0);
  fragColor = vec4(c * a, a);
}
