#include <flutter/runtime_effect.glsl>

// Порт "Galaxy" из react-bits (reactbits.dev, MIT) — hash-based процедурная
// генерация звёзд в NUM_LAYER слоях глубины (параллакс-скролл), мерцание
// через треугольную волну по времени, HSV-сдвиг цвета. Построчный перенос
// оригинального WebGL/OGL фрагмент-шейдера, см. ROADMAP.md, "Фон —
// шейдерные эффекты".
//
// Упрощено так же, как color_bends.frag/simple_gradient.frag —
// настраиваемые uniform'ы оригинала (density/hueShift/glowIntensity/...)
// зафиксированы константами со значениями по умолчанию из react-bits.
// Убрана mouse-интерактивность (repulsion, офсет фокуса под курсор) — у
// `ShaderBackground` (lib/widgets/globe/shader_background.dart) нет
// пайплайна для передачи позиции мыши в шейдер; убрано и ручное вращение
// (`uRotation` оригинала) — оставлена только авто-ротация. Всегда
// непрозрачный (`transparent: true` оригинала не имеет смысла для
// полноэкранного фона, который и так базовый слой).
//
// `uStarSpeed` оригинала — отдельный аккумулятор, инкрементируемый JS-хуком
// каждый кадр на `delta * speed * starSpeed`; здесь это просто `uTime *
// STAR_SPEED` — не точная копия таймлайна оригинала, но та же роль
// (равномерно растущий счётчик, двигающий параллакс-слои).

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

#define NUM_LAYER 4.0
#define STAR_COLOR_CUTOFF 0.2
#define MAT45 mat2(0.7071, -0.7071, 0.7071, 0.7071)
#define PERIOD 3.0

const float DENSITY = 1.0;
const float HUE_SHIFT = 140.0;
// SPEED/ROTATION_SPEED/STAR_SPEED уменьшены против дефолтов react-bits —
// оригинальные значения (1.0/0.1/0.5) на полноэкранном фоне ощущались
// слишком суетливыми (мерцание и параллакс-скролл звёзд бросались в глаза
// вместо спокойного фона).
const float SPEED = 0.35;
const float GLOW_INTENSITY = 0.3;
const float SATURATION = 0.0;
const float TWINKLE_INTENSITY = 0.3;
const float ROTATION_SPEED = 0.03;
const float STAR_SPEED = 0.15;

float Hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float tri(float x) {
  return abs(fract(x) * 2.0 - 1.0);
}

float tris(float x) {
  float t = fract(x);
  return 1.0 - smoothstep(0.0, 1.0, abs(2.0 * t - 1.0));
}

float trisn(float x) {
  float t = fract(x);
  return 2.0 * (1.0 - smoothstep(0.0, 1.0, abs(2.0 * t - 1.0))) - 1.0;
}

vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float Star(vec2 uv, float flare) {
  float d = length(uv);
  float m = (0.05 * GLOW_INTENSITY) / d;
  float rays = smoothstep(0.0, 1.0, 1.0 - abs(uv.x * uv.y * 1000.0));
  m += rays * flare * GLOW_INTENSITY;
  uv *= MAT45;
  rays = smoothstep(0.0, 1.0, 1.0 - abs(uv.x * uv.y * 1000.0));
  m += rays * 0.3 * flare * GLOW_INTENSITY;
  m *= smoothstep(1.0, 0.2, d);
  return m;
}

vec3 StarLayer(vec2 uv, float starSpeedValue) {
  vec3 col = vec3(0.0);

  vec2 gv = fract(uv) - 0.5;
  vec2 id = floor(uv);

  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 offset = vec2(float(x), float(y));
      vec2 si = id + offset;
      float seed = Hash21(si);
      float size = fract(seed * 345.32);
      float glossLocal = tri(starSpeedValue / (PERIOD * seed + 1.0));
      float flareSize = smoothstep(0.9, 1.0, size) * glossLocal;

      float red = smoothstep(STAR_COLOR_CUTOFF, 1.0, Hash21(si + 1.0)) + STAR_COLOR_CUTOFF;
      float blu = smoothstep(STAR_COLOR_CUTOFF, 1.0, Hash21(si + 3.0)) + STAR_COLOR_CUTOFF;
      float grn = min(red, blu) * seed;
      vec3 base = vec3(red, grn, blu);

      float hue = atan(base.g - base.r, base.b - base.r) / (2.0 * 3.14159) + 0.5;
      hue = fract(hue + HUE_SHIFT / 360.0);
      float sat = length(base - vec3(dot(base, vec3(0.299, 0.587, 0.114)))) * SATURATION;
      float val = max(max(base.r, base.g), base.b);
      base = hsv2rgb(vec3(hue, sat, val));

      vec2 pad = vec2(
        tris(seed * 34.0 + uTime * SPEED / 10.0),
        tris(seed * 38.0 + uTime * SPEED / 30.0)
      ) - 0.5;

      float star = Star(gv - offset - pad, flareSize);
      vec3 color = base;

      float twinkle = trisn(uTime * SPEED + seed * 6.2831) * 0.5 + 1.0;
      twinkle = mix(1.0, twinkle, TWINKLE_INTENSITY);
      star *= twinkle;

      col += star * size * color;
    }
  }

  return col;
}

void main() {
  vec2 uv = (FlutterFragCoord().xy - 0.5 * uSize) / uSize.y;

  float autoRotAngle = uTime * ROTATION_SPEED;
  mat2 autoRot = mat2(
    cos(autoRotAngle), -sin(autoRotAngle),
    sin(autoRotAngle), cos(autoRotAngle)
  );
  uv = autoRot * uv;

  float starSpeedValue = uTime * STAR_SPEED;

  vec3 col = vec3(0.0);

  for (float i = 0.0; i < 1.0; i += 1.0 / NUM_LAYER) {
    float depth = fract(i + starSpeedValue * SPEED);
    float scale = mix(20.0 * DENSITY, 0.5 * DENSITY, depth);
    float fade = depth * smoothstep(1.0, 0.9, depth);
    col += StarLayer(uv * scale + i * 453.32, starSpeedValue) * fade;
  }

  fragColor = vec4(col, 1.0);
}
