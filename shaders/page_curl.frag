// «انحناء الورقة»: the turning page wrapped round a cylinder that lies on
// the page and rolls toward the spine. Everything here is in the page's
// logical pixels.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;   // the page's size
uniform vec2 uN;      // unit vector across the axis, toward the free edge
uniform float uA;     // the axis: dot(p, uN) at the axis
uniform float uR;     // the cylinder's radius
uniform float uNext;  // 1 when uNextPage holds the page beneath
uniform sampler2D uPage;
uniform sampler2D uNextPage;

out vec4 fragColor;

const float PI = 3.14159265;
const vec3 PAPER = vec3(0.969, 0.953, 0.918);

bool inside(vec2 q) {
  return q.x >= 0.0 && q.y >= 0.0 && q.x <= uSize.x && q.y <= uSize.y;
}

// The page beneath at p, darkened by the curl's shadow [k].
vec4 beneath(vec2 p, float k) {
  if (uNext < 0.5) return vec4(0.0);
  vec4 c = texture(uNextPage, p / uSize);
  return vec4(c.rgb * (1.0 - k), c.a);
}

// The back of the paper at q: its print faint through it, lit by [light].
vec4 back(vec2 q, float light) {
  vec3 c = texture(uPage, q / uSize).rgb;
  vec3 seen = mix(PAPER, c, 0.12);
  return vec4(seen * light, 1.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float d = dot(p, uN) - uA;

  if (d > uR) {
    // Uncovered: the next page, in the curl's soft shadow.
    float k = 0.35 * exp(-(d - uR) / (0.9 * uR));
    fragColor = beneath(p, k);
    return;
  }

  if (d >= 0.0) {
    // Over the cylinder: its far (back) side is on top, then its near
    // (front) side.
    float t1 = asin(clamp(d / uR, 0.0, 1.0));
    float t2 = PI - t1;
    vec2 qb = p + uN * (uR * t2 - d);
    if (inside(qb)) {
      // Lit along its crest, a specular line, darker as it turns down.
      float light = 0.80 + 0.22 * sin(t2) + 0.10 * pow(sin(t2), 24.0);
      fragColor = back(qb, light);
      return;
    }
    vec2 qf = p + uN * (uR * t1 - d);
    if (inside(qf)) {
      vec4 c = texture(uPage, qf / uSize);
      float light = 0.62 + 0.38 * cos(t1) + 0.18 * pow(sin(t1), 30.0);
      fragColor = vec4(c.rgb * light, c.a);
      return;
    }
    fragColor = beneath(p, 0.35);
    return;
  }

  // Behind the axis: the flap laid back over the page, else the page.
  vec2 qb = p + uN * (PI * uR - 2.0 * d);
  if (inside(qb)) {
    float light = 0.80 + 0.06 * exp(d / uR);
    fragColor = back(qb, light);
    return;
  }
  vec4 c = texture(uPage, p / uSize);
  // The flap's shadow, close to where it lies.
  fragColor = vec4(c.rgb * (1.0 - 0.18 * exp(d / (0.6 * uR))), c.a);
}
