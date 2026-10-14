// «انحناء الورقة» on two facing pages (the mushaf is right to left): the
// left page is the leaf. It rolls round a cylinder from its free edge (the
// left) toward the spine, and the rolled part lies back over the spine and
// down onto the right page, showing the leaf's back: the next spread's
// right page. Under the leaf: the next spread's left page; on the right,
// until the leaf covers it, this spread's right page. Everything here is
// in the spread's logical pixels.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;   // the spread's size; the spine is at uSize.x / 2
uniform vec2 uN;      // unit vector across the axis, toward the free edge
uniform float uA;     // the axis: dot(p, uN) at the axis
uniform float uR;     // the cylinder's radius
uniform sampler2D uFront;  // the leaf: this spread's left page
uniform sampler2D uBack;   // its back: the next spread's right page
uniform sampler2D uUnder;  // the next spread's left page
uniform sampler2D uRight;  // this spread's right page

out vec4 fragColor;

const float PI = 3.14159265;

float half_w() { return uSize.x * 0.5; }

bool onLeaf(vec2 q) {
  return q.x >= 0.0 && q.y >= 0.0 && q.x <= half_w() && q.y <= uSize.y;
}

vec4 front(vec2 q, float light) {
  vec4 c = texture(uFront, vec2(q.x / half_w(), q.y / uSize.y));
  return vec4(c.rgb * light, c.a);
}

// The back of the leaf at q: the next right page, where q lands once the
// leaf lies flat on the right (mirrored across the spine).
vec4 back(vec2 q, float light) {
  vec4 c = texture(uBack, vec2((half_w() - q.x) / half_w(), q.y / uSize.y));
  return vec4(c.rgb * light, c.a);
}

// What lies under the leaf at p, darkened by its shadow [k].
vec4 beneath(vec2 p, float k) {
  vec4 c;
  if (p.x < half_w()) {
    c = texture(uUnder, vec2(p.x / half_w(), p.y / uSize.y));
  } else {
    c = texture(uRight, vec2((p.x - half_w()) / half_w(), p.y / uSize.y));
  }
  return vec4(c.rgb * (1.0 - k), c.a);
}

// [top] over [under]; colours are premultiplied, and the pages' margins
// are transparent (the app's background shows there).
vec4 over(vec4 top, vec4 under) {
  return top + under * (1.0 - top.a);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float r = max(uR, 0.5);
  float d = dot(p, uN) - uA;

  if (d > r) {
    // Beyond the cylinder: the leaf has rolled away; its soft shadow.
    float k = 0.35 * exp(-(d - r) / (0.9 * r));
    fragColor = beneath(p, k);
    return;
  }

  if (d >= 0.0) {
    // Over the cylinder: its far (back) side on top, then its near side.
    float t1 = asin(clamp(d / r, 0.0, 1.0));
    float t2 = PI - t1;
    vec2 qb = p + uN * (r * t2 - d);
    if (onLeaf(qb)) {
      float light = 0.78 + 0.22 * sin(t2) + 0.10 * pow(sin(t2), 24.0);
      vec2 qf0 = p + uN * (r * t1 - d);
      vec4 below = onLeaf(qf0)
          ? over(front(qf0, 0.62 + 0.38 * cos(t1)), beneath(p, 0.35))
          : beneath(p, 0.35);
      fragColor = over(back(qb, light), below);
      return;
    }
    vec2 qf = p + uN * (r * t1 - d);
    if (onLeaf(qf)) {
      float light = 0.62 + 0.38 * cos(t1) + 0.18 * pow(sin(t1), 30.0);
      fragColor = over(front(qf, light), beneath(p, 0.35));
      return;
    }
    fragColor = beneath(p, 0.35);
    return;
  }

  // Behind the axis: the rolled part laid back on top, else the flat leaf,
  // else the page under it (the right page, near the spine).
  vec2 qb = p + uN * (PI * r - 2.0 * d);
  vec4 flat_ = onLeaf(p)
      ? over(front(p, 1.0 - 0.18 * exp(d / (0.6 * r))), beneath(p, 0.0))
      : beneath(p, 0.0);
  if (onLeaf(qb)) {
    // Darker toward the cylinder, where it bends.
    float light = 0.84 + 0.16 * (1.0 - exp(d / r));
    fragColor = over(back(qb, light), flat_);
    return;
  }
  // The rolled part's shadow on what it lies over, close to its edge.
  float k = 0.22 * exp(-length(qb - clamp(qb, vec2(0.0), vec2(half_w(), uSize.y))) / (0.5 * r + 6.0));
  if (onLeaf(p)) {
    fragColor = flat_;
    return;
  }
  fragColor = beneath(p, k);
}
