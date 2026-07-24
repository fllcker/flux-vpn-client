import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Текущий угол вращения глобуса — публикуется через [GlobeRotationController]
/// для внешних слоёв (например, `Starfield`), которым нужно двигаться
/// синхронно с вращением, не будучи частью самого `SphereGlobe`.
class GlobeRotation {
  final double phi;
  final double theta;
  const GlobeRotation(this.phi, this.theta);
}

class GlobeRotationController extends ValueNotifier<GlobeRotation> {
  GlobeRotationController({double initialTheta = -0.25})
    : super(GlobeRotation(0, initialTheta));
}

/// Точка на глобусе с подписью — например, страна выбранного сервера.
/// [label] уже полностью стилизован вызывающей стороной (флаг, текст,
/// фон таблички), сам глобус не хардкодит цветовую схему таблички.
class GlobeMarker {
  final double lat;
  final double lon;
  final Widget label;

  const GlobeMarker({required this.lat, required this.lon, required this.label});
}

/// Вращаемый точечный глобус в духе cobe (https://cobe.vercel.app) —
/// точки рассеяны только по суше (см. `assets/globe/land_mask.png`, взятую
/// из самого cobe — см. `assets/globe/NOTICE.md`), с псевдо-освещением,
/// свечением по краю и авто-вращением, которое можно перебить
/// перетаскиванием. Вся палитра — один [color]: точки, свечение и акцентная
/// метка — это его производные по альфе, так что глобус красится под тему
/// приложения целиком, а не только под фиолетовый.
class SphereGlobe extends StatefulWidget {
  final Color color;
  final bool autoRotate;

  /// Скорость авто-вращения, радиан/сек.
  final double autoRotateSpeed;

  /// Сколько кандидатов сэмплируется по сфере перед фильтрацией по маске
  /// суши — итоговое число видимых точек будет в разы меньше (суша — это
  /// ~29% поверхности Земли).
  final int candidateCount;

  /// Начальный наклон вокруг горизонтальной оси, радианы.
  final double initialTheta;
  final List<GlobeMarker> markers;

  /// Опционально — публикует текущий phi/theta наружу (см.
  /// [GlobeRotationController]), чтобы синхронизировать с ним другие слои
  /// фона, например звёздное поле.
  final GlobeRotationController? rotationController;

  const SphereGlobe({
    super.key,
    required this.color,
    this.autoRotate = true,
    this.autoRotateSpeed = 0.12,
    this.candidateCount = 20000,
    this.initialTheta = -0.25,
    this.markers = const [],
    this.rotationController,
  });

  @override
  State<SphereGlobe> createState() => _SphereGlobeState();
}

const _radiusFactor = 0.86;

class _SphereGlobeState extends State<SphereGlobe>
    with SingleTickerProviderStateMixin {
  List<_SpherePoint>? _points;
  late double _phi = 0;
  late double _theta = widget.initialTheta;
  bool _dragging = false;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  static const _thetaLimit = pi / 2 - 0.05;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadLandMask().then((mask) {
      if (!mounted) return;
      setState(() {
        _points = _landPoints(mask, widget.candidateCount);
      });
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (widget.autoRotate && !_dragging) {
      setState(() => _phi += dt * widget.autoRotateSpeed);
      _publishRotation();
    }
  }

  void _onPanStart(DragStartDetails details) {
    _dragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _phi += details.delta.dx * 0.008;
      _theta = (_theta + details.delta.dy * 0.008).clamp(
        -_thetaLimit,
        _thetaLimit,
      );
    });
    _publishRotation();
  }

  void _publishRotation() {
    widget.rotationController?.value = GlobeRotation(_phi, _theta);
  }

  void _onPanEnd(DragEndDetails details) {
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final center = size.center(Offset.zero);
        final radius = min(size.width, size.height) / 2 * _radiusFactor;
        final cosPhi = cos(_phi), sinPhi = sin(_phi);
        final cosTheta = cos(_theta), sinTheta = sin(_theta);

        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: () => _dragging = false,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: points == null
                      ? null
                      : _GlobePainter(
                          points: points,
                          markers: widget.markers,
                          phi: _phi,
                          theta: _theta,
                          color: widget.color,
                        ),
                ),
              ),
              for (final marker in widget.markers)
                ..._buildMarkerLabel(
                  marker,
                  center,
                  radius,
                  cosPhi,
                  sinPhi,
                  cosTheta,
                  sinTheta,
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildMarkerLabel(
    GlobeMarker marker,
    Offset center,
    double radius,
    double cosPhi,
    double sinPhi,
    double cosTheta,
    double sinTheta,
  ) {
    final rotated = _rotateLatLon(
      marker.lat,
      marker.lon,
      cosPhi,
      sinPhi,
      cosTheta,
      sinTheta,
    );
    final visible = rotated.z > -0.05;
    final depth = ((rotated.z + 1) / 2).clamp(0.0, 1.0);
    final screen = center + Offset(rotated.x, -rotated.y) * radius;

    // Позиция двигается через Transform (композитинг), а не Positioned
    // left/top (релэйаут) — Positioned на каждый кадр перекладывал текст
    // заново, из-за чего при медленном вращении округление до пикселя
    // давало заметные "скачки" вместо плавного скольжения.
    return [
      Positioned.fill(
        child: IgnorePointer(
          ignoring: !visible,
          child: Transform.translate(
            offset: screen,
            child: Align(
              alignment: Alignment.topLeft,
              child: AnimatedOpacity(
                opacity: visible ? (0.35 + 0.65 * depth) : 0.0,
                duration: const Duration(milliseconds: 150),
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -1.35),
                  child: marker.label,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _SpherePoint {
  final double x;
  final double y;
  final double z;
  const _SpherePoint(this.x, this.y, this.z);
}

class _Rotated {
  final double x;
  final double y;
  final double z;
  const _Rotated(this.x, this.y, this.z);
}

_Rotated _rotate(
  _SpherePoint p,
  double cosPhi,
  double sinPhi,
  double cosTheta,
  double sinTheta,
) {
  final x1 = p.x * cosPhi + p.z * sinPhi;
  final z1 = -p.x * sinPhi + p.z * cosPhi;
  final y1 = p.y;

  final y2 = y1 * cosTheta - z1 * sinTheta;
  final z2 = y1 * sinTheta + z1 * cosTheta;
  final x2 = x1;
  return _Rotated(x2, y2, z2);
}

_Rotated _rotateLatLon(
  double lat,
  double lon,
  double cosPhi,
  double sinPhi,
  double cosTheta,
  double sinTheta,
) {
  final p = _unitPointFromLatLon(lat, lon);
  return _rotate(p, cosPhi, sinPhi, cosTheta, sinTheta);
}

_SpherePoint _unitPointFromLatLon(double lat, double lon) {
  final latRad = lat * pi / 180;
  final lonRad = lon * pi / 180;
  final y = sin(latRad);
  final r = cos(latRad);
  final x = r * sin(lonRad);
  final z = r * cos(lonRad);
  return _SpherePoint(x, y, z);
}

/// Равномерно (Fibonacci sphere sampling — без сгущения у полюсов, в
/// отличие от lat/lon-сетки) раскидывает кандидатов по сфере и оставляет
/// только те, что попали на сушу по `mask`. Вероятность оставить точку у
/// края побережья равна яркости маски в этой точке — так антиалиасинг
/// текстуры превращается в мягкую, а не рваную границу континентов.
List<_SpherePoint> _landPoints(_LandMask mask, int candidateCount) {
  final random = Random(42);
  final points = <_SpherePoint>[];
  const goldenAngle = pi * (3 - 2.2360679774997896); // pi * (3 - sqrt(5))

  for (var i = 0; i < candidateCount; i++) {
    final y = 1 - (i / (candidateCount - 1)) * 2;
    final radiusAtY = sqrt(max(0, 1 - y * y));
    final theta = goldenAngle * i;
    final x = cos(theta) * radiusAtY;
    final z = sin(theta) * radiusAtY;

    final lat = asin(y.clamp(-1.0, 1.0)) * 180 / pi;
    final lon = atan2(x, z) * 180 / pi;
    final coverage = mask.coverageAt(lat, lon);
    if (coverage > 0.06 && random.nextDouble() < coverage) {
      points.add(_SpherePoint(x, y, z));
    }
  }
  return points;
}

class _LandMask {
  final int width;
  final int height;
  final Uint8List rgba;

  const _LandMask(this.width, this.height, this.rgba);

  /// lat: -90..90 (юг..север), lon: -180..180.
  double coverageAt(double lat, double lon) {
    final u = ((lon + 180) / 360) % 1.0;
    final v = ((90 - lat) / 180).clamp(0.0, 0.999999);
    final x = (u * width).floor().clamp(0, width - 1);
    final y = (v * height).floor().clamp(0, height - 1);
    final idx = (y * width + x) * 4;
    return rgba[idx] / 255.0;
  }
}

Future<_LandMask>? _cachedLandMask;

Future<_LandMask> _loadLandMask() {
  return _cachedLandMask ??= () async {
    final data = await rootBundle.load('assets/globe/land_mask.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    return _LandMask(image.width, image.height, byteData!.buffer.asUint8List());
  }();
}

/// Фиксированное в мировых координатах направление света для псевдо-объёма
/// точек — верхний левый перед, как обычно освещают глобусы у cobe.
const _lightX = -0.4, _lightY = 0.55, _lightZ = 0.85;

class _GlobePainter extends CustomPainter {
  final List<_SpherePoint> points;
  final List<GlobeMarker> markers;
  final double phi;
  final double theta;
  final Color color;

  _GlobePainter({
    required this.points,
    required this.markers,
    required this.phi,
    required this.theta,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2 * _radiusFactor;

    final cosPhi = cos(phi), sinPhi = sin(phi);
    final cosTheta = cos(theta), sinTheta = sin(theta);

    final lightLen = sqrt(
      _lightX * _lightX + _lightY * _lightY + _lightZ * _lightZ,
    );
    final lx = _lightX / lightLen,
        ly = _lightY / lightLen,
        lz = _lightZ / lightLen;

    // Мягкий ореол за краем сферы — иначе на тёмном фоне шар сливается с
    // фоном и точки читаются просто как рассыпанные крапинки.
    final haloPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.12
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.18);
    canvas.drawCircle(center, radius * 1.02, haloPaint);

    // Тело сферы — мягкий радиальный градиент со смещённым "бликом" плюс
    // тонкий обвод по краю, чтобы читался объём шара.
    final highlightOffset = Offset(-radius * 0.32, -radius * 0.32);
    final bodyPaint = Paint()
      ..shader = ui.Gradient.radial(center + highlightOffset, radius * 1.6, [
        color.withValues(alpha: 0.16),
        color.withValues(alpha: 0.05),
        color.withValues(alpha: 0.0),
      ], const [0.0, 0.55, 1.0]);
    canvas.drawCircle(center, radius, bodyPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.28);
    canvas.drawCircle(center, radius, rimPaint);

    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in points) {
      final r = _rotate(p, cosPhi, sinPhi, cosTheta, sinTheta);
      if (r.z < -0.05) continue; // дальняя половина сферы не видна

      final screen = center + Offset(r.x, -r.y) * radius;

      final brightness = ((r.x * lx + r.y * ly + r.z * lz) + 1) / 2;
      final depth = (r.z + 1) / 2;
      final alpha = ((0.25 + 0.75 * brightness) * (0.35 + 0.65 * depth))
          .clamp(0.0, 1.0);
      final dotRadius = 1.0 + 0.7 * depth;

      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(screen, dotRadius, paint);
    }

    for (final marker in markers) {
      final r = _rotateLatLon(
        marker.lat,
        marker.lon,
        cosPhi,
        sinPhi,
        cosTheta,
        sinTheta,
      );
      if (r.z < -0.05) continue;
      final screen = center + Offset(r.x, -r.y) * radius;
      final depth = (r.z + 1) / 2;

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.55 * depth)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(screen, 9, glowPaint);

      final dotPaint = Paint()
        ..color = color.withValues(alpha: (0.7 + 0.3 * depth).clamp(0, 1));
      canvas.drawCircle(screen, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) {
    return oldDelegate.phi != phi ||
        oldDelegate.theta != theta ||
        oldDelegate.color != color ||
        !identical(oldDelegate.points, points) ||
        !identical(oldDelegate.markers, markers);
  }
}
