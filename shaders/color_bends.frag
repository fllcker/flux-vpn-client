#include <flutter/runtime_effect.glsl>

// Быстрый прототип "Color Bends" из react-bits (reactbits.dev, MIT) —
// портирован построчно с оригинального GLSL-фрагментного шейдера
// (ColorBends.tsx, Three.js), домейн-warping через сумму синусоид даёт
// перетекающие цветовые полосы. Упрощено под прототип: фиксированные
// 3 цвета и параметры вместо настраиваемых uniform'ов оригинала — если
// эффект понравится, вынести ITERATIONS/FREQUENCY/цвета в uniform'ы для
// реальной интеграции (см. ROADMAP.md, "Фон — шейдерные эффекты").

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

const int ITERATIONS = 5;
const float SPEED = 0.12;
const float SCALE = 1.0;
const float FREQUENCY = 1.2;
const float WARP_STRENGTH = 1.0;
// BAND_WIDTH — резкость затухания полос: маленькое значение (было 1.6)
// растягивает "ленту" в мягкий толстый градиент; большое даёт тонкие яркие
// нити почти на чёрном фоне, как в оригинале react-bits. 9.0 при SCALE=1.5
// увело паттерн за пределы экрана — держим SCALE как в исходнике и берём
// BAND_WIDTH умереннее.
const float BAND_WIDTH = 4.0;
const float INTENSITY = 1.3;

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

  // Два близких оттенка вместо трёх контрастных — референс на reactbits.dev
  // выглядит как одна лента, а не размытая смесь холодных и тёплых цветов.
  vec3 colors[2];
  colors[0] = vec3(0.55, 0.25, 0.95); // violet
  colors[1] = vec3(0.75, 0.20, 0.85); // magenta

  vec3 col = vec3(0.0);
  float cover = 0.0;
  vec2 s = q;

  for (int i = 0; i < 2; i++) {
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
