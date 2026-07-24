import 'dart:math';

import 'package:flutter/widgets.dart';

import 'sphere_globe.dart';

/// Поле мелких точек-«звёзд» на весь фон, очень низкая плотность/яркость,
/// чтобы не спорить с глобусом за внимание. Позиции — доли (0..1) от
/// размера, тайлится с бесшовным заворотом (`%`), поэтому один и тот же
/// набор растягивается на любой размер контейнера.
///
/// Если передан [rotation] (тот же контроллер, что и у `SphereGlobe`),
/// звёзды едут вместе с вращением глобуса — не потому что вращается сама
/// Земля, а потому что меняется наша точка обзора (как в Apple Maps):
/// поворачивая взгляд, мы видим смещающийся задний план неба.
class Starfield extends StatelessWidget {
  final Color color;
  final int count;
  final GlobeRotationController? rotation;

  /// Сколько пикселей проезжают звёзды на один радиан поворота — держим
  /// близко к видимому радиусу глобуса, чтобы скорость сдвига звёзд на
  /// глаз совпадала со скоростью его поверхности.
  final double pixelsPerRadian;

  const Starfield({
    super.key,
    required this.color,
    this.count = 90,
    this.rotation,
    this.pixelsPerRadian = 240,
  });

  @override
  Widget build(BuildContext context) {
    final stars = _stars(count);
    final rotation = this.rotation;
    if (rotation == null) {
      return CustomPaint(
        size: Size.infinite,
        painter: _StarfieldPainter(stars: stars, color: color, offset: Offset.zero),
      );
    }

    return AnimatedBuilder(
      animation: rotation,
      builder: (context, _) {
        final r = rotation.value;
        return CustomPaint(
          size: Size.infinite,
          painter: _StarfieldPainter(
            stars: stars,
            color: color,
            offset: Offset(r.phi, r.theta) * pixelsPerRadian,
          ),
        );
      },
    );
  }
}

class _Star {
  final double dx;
  final double dy;
  final double radius;
  final double alpha;
  const _Star(this.dx, this.dy, this.radius, this.alpha);
}

final _cache = <int, List<_Star>>{};

List<_Star> _stars(int count) {
  return _cache.putIfAbsent(count, () {
    final random = Random(7);
    return List.generate(count, (_) {
      return _Star(
        random.nextDouble(),
        random.nextDouble(),
        0.5 + random.nextDouble() * 0.9,
        0.08 + random.nextDouble() * 0.22,
      );
    });
  });
}

class _StarfieldPainter extends CustomPainter {
  final List<_Star> stars;
  final Color color;
  final Offset offset;

  _StarfieldPainter({
    required this.stars,
    required this.color,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final star in stars) {
      final x = _wrap(star.dx * size.width - offset.dx, size.width);
      final y = _wrap(star.dy * size.height - offset.dy, size.height);
      paint.color = color.withValues(alpha: star.alpha);
      canvas.drawCircle(Offset(x, y), star.radius, paint);
    }
  }

  static double _wrap(double value, double period) {
    if (period <= 0) return 0;
    return ((value % period) + period) % period;
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.offset != offset ||
        !identical(oldDelegate.stars, stars);
  }
}
