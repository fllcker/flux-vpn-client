#include <flutter/runtime_effect.glsl>

// "Simple Gradient" — побочный результат первой (неудачной как копия
// Color Bends, но приятной самой по себе) попытки портировать эффект:
// мягкий толстый переливающийся градиент вместо тонких светящихся нитей
// оригинала. Оставлен как самостоятельный, более спокойный вариант фона —
// см. ROADMAP.md, "Фон — шейдерные эффекты". Тот же домейн-warping через
// сумму синусоид, что и в color_bends.frag, просто с низким BAND_WIDTH —
// полосы затухают медленно и сливаются в широкий градиент, а не в резкие
// нити на чёрном фоне.

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

const int ITERATIONS = 5;
const float SPEED = 0.12;
const float SCALE = 1.0;
const float FREQUENCY = 1.2;
const float WARP_STRENGTH = 1.0;
const float BAND_WIDTH = 1.6;
const float INTENSITY = 0.5;

void main() {
  float t = uTime * SPEED;
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 p = uv * 2.0 - 1.0;
  vec2 q = vec2(p.x * (uSize.x / uSize.y), p.y) / SCALE;
  q /= 0.5 + 0.2 * dot(q, q);
  q += 0.2 * cos(t) - 7.56;

  for (int j = 0; j < ITERATIONS; j++) {
    vec2 rr = sin(1.5 * (q.yx * FREQUENCY) + 2.0 * cos(q * FREQUENCY));
    q += (rr - q) * 0.15;
  }

  vec3 colors[3];
  colors[0] = vec3(0.42, 0.35, 0.95); // violet
  colors[1] = vec3(0.25, 0.55, 0.95); // blue
  colors[2] = vec3(0.30, 0.85, 0.85); // cyan

  vec3 col = vec3(0.0);
  float cover = 0.0;
  vec2 s = q;

  for (int i = 0; i < 3; i++) {
    s -= 0.01;
    vec2 r = sin(1.5 * (s.yx * FREQUENCY) + 2.0 * cos(s * FREQUENCY));
    float m0 = length(r + sin(5.0 * r.y * FREQUENCY - 3.0 * t + float(i)) / 4.0);
    vec2 disp = (r - s) * WARP_STRENGTH;
    vec2 warped = s + disp;
    float m1 = length(warped + sin(5.0 * warped.y * FREQUENCY - 3.0 * t + float(i)) / 4.0);
    float m = mix(m0, m1, 0.6);
    float w = 1.0 - exp(-BAND_WIDTH / exp(BAND_WIDTH * m));
    col += colors[i] * w;
    cover = max(cover, w);
  }

  col = clamp(col, 0.0, 1.0) * INTENSITY;
  fragColor = vec4(col, cover * INTENSITY);
}
