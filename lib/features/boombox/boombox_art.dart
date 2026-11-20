import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'tape_library.dart';

const deckRect = Rect.fromLTWH(334, 152, 232, 148);

class CassetteArt extends StatelessWidget {
  final Tape tape;
  final double rotation;
  const CassetteArt({super.key, required this.tape, this.rotation = 0});

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.6,
    child: CustomPaint(painter: _CassettePainter(tape.title, rotation)),
  );
}

void _text(
  Canvas canvas,
  String value,
  Offset at,
  double size,
  Color color, {
  double maxWidth = double.infinity,
  FontWeight weight = FontWeight.normal,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        fontFamily: 'monospace',
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  painter.paint(canvas, at);
}

void _screw(Canvas canvas, Offset at, [double radius = 3]) {
  canvas.drawCircle(
    at + const Offset(0, 1),
    radius + 1,
    Paint()..color = Colors.black54,
  );
  canvas.drawCircle(
    at,
    radius,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFAAAAA6), Color(0xFF333633)],
      ).createShader(Rect.fromCircle(center: at, radius: radius)),
  );
  canvas.drawLine(
    at - Offset(radius * .65, 0),
    at + Offset(radius * .65, 0),
    Paint()
      ..color = Colors.black87
      ..strokeWidth = 1,
  );
}

class _CassettePainter extends CustomPainter {
  final String title;
  final double rotation;
  _CassettePainter(this.title, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 150);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3, 3, 234, 140),
      const Radius.circular(10),
    );
    canvas.drawShadow(Path()..addRRect(body), Colors.black, 6, false);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF55504A), Color(0xFF181B1B), Color(0xFF363A38)],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF77756B)
        ..strokeWidth = .8,
    );
    final hue = title.codeUnits.fold<int>(0, (a, b) => a + b) % 3;
    final stripe = [
      const Color(0xFFB7482E),
      const Color(0xFF486B6C),
      const Color(0xFFAE7A2B),
    ][hue];
    final label = RRect.fromRectAndRadius(
      const Rect.fromLTWH(15, 14, 210, 91),
      const Radius.circular(5),
    );
    canvas.drawRRect(label, Paint()..color = const Color(0xFFE1D7B8));
    canvas.drawRect(
      const Rect.fromLTWH(16, 43, 208, 10),
      Paint()..color = stripe,
    );
    _text(
      canvas,
      title,
      const Offset(24, 22),
      12,
      const Color(0xFF252A27),
      maxWidth: 192,
      weight: FontWeight.bold,
    );
    _text(
      canvas,
      'A',
      const Offset(23, 65),
      17,
      stripe,
      weight: FontWeight.bold,
    );
    _text(
      canvas,
      'FLUX  •  C90',
      const Offset(133, 91),
      7,
      const Color(0xFF3D413B),
    );
    final window = RRect.fromRectAndRadius(
      const Rect.fromLTWH(48, 59, 146, 31),
      const Radius.circular(12),
    );
    canvas.drawRRect(window, Paint()..color = const Color(0xFF151C19));
    canvas.drawLine(
      const Offset(68, 81),
      const Offset(174, 81),
      Paint()
        ..color = const Color(0xFF735139)
        ..strokeWidth = 3,
    );
    for (final x in [73.0, 168.0]) {
      canvas.drawCircle(
        Offset(x, 75),
        21,
        Paint()..color = const Color(0xFF533C28),
      );
      for (var r = 12.0; r < 21; r += 2) {
        canvas.drawCircle(
          Offset(x, 75),
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.black26
            ..strokeWidth = .5,
        );
      }
      canvas.save();
      canvas.translate(x, 75);
      canvas.rotate(rotation);
      canvas.drawCircle(
        Offset.zero,
        11,
        Paint()..color = const Color(0xFFD5D5C6),
      );
      for (var i = 0; i < 6; i++) {
        canvas.rotate(math.pi / 3);
        canvas.drawRect(
          const Rect.fromLTWH(-2, 4, 4, 6),
          Paint()..color = const Color(0xFF4B5049),
        );
      }
      canvas.drawCircle(
        Offset.zero,
        4,
        Paint()..color = const Color(0xFF121714),
      );
      canvas.restore();
    }
    final base = Path()
      ..moveTo(40, 137)
      ..lineTo(54, 112)
      ..lineTo(186, 112)
      ..lineTo(200, 137)
      ..close();
    canvas.drawPath(base, Paint()..color = const Color(0xFF222826));
    for (final x in [62.0, 91.0, 149.0, 178.0]) {
      canvas.drawCircle(
        Offset(x, 127),
        x == 91 || x == 149 ? 4 : 2,
        Paint()..color = Colors.black,
      );
    }
    for (final point in [
      const Offset(11, 11),
      const Offset(229, 11),
      const Offset(11, 133),
      const Offset(229, 133),
      const Offset(120, 117),
    ]) {
      _screw(canvas, point, 2.5);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CassettePainter old) =>
      title != old.title || rotation != old.rotation;
}

class BoomboxPainter extends CustomPainter {
  final bool playing;
  final bool accepting;
  final double phase;
  const BoomboxPainter({
    this.playing = false,
    this.accepting = false,
    this.phase = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 900, size.height / 450);
    // Raised carrying handle and its inset highlight.
    final handle = RRect.fromRectAndRadius(
      const Rect.fromLTWH(255, 11, 390, 105),
      const Radius.circular(28),
    );
    canvas.drawRRect(handle, Paint()..color = const Color(0xFF171D20));
    canvas.drawRRect(
      handle.deflate(12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF586062),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(283, 37, 334, 70),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFF242D32),
    );
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 73, 868, 343),
      const Radius.circular(25),
    );
    canvas.drawShadow(Path()..addRRect(body), Colors.black, 24, true);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFCBCDC6),
            Color(0xFF7B8585),
            Color(0xFFB9BDB6),
            Color(0xFF555F60),
          ],
          stops: [0, .17, .7, 1],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body.deflate(5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFDFE0D7),
    );
    // Fine brushed-metal grain stays deterministic and scales with the case.
    for (var y = 90.0; y < 409; y += 3) {
      canvas.drawLine(
        Offset(36, y),
        Offset(864, y),
        Paint()
          ..color = Colors.black.withValues(
            alpha: y.toInt().isEven ? .025 : .045,
          )
          ..strokeWidth = .5,
      );
    }
    for (final x in [175.0, 725.0]) {
      final center = Offset(x, 258);
      canvas.drawCircle(center, 131, Paint()..color = const Color(0xFF414B4B));
      canvas.drawCircle(
        center,
        126,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF111618), Color(0xFF394142), Color(0xFF090E10)],
            stops: [0, .8, 1],
          ).createShader(Rect.fromCircle(center: center, radius: 126)),
      );
      for (var radius = 44.0; radius < 118; radius += 6) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF4A5252).withValues(alpha: .45),
        );
      }
      canvas.drawCircle(
        center,
        43,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.4, -.5),
            colors: [Color(0xFF66706D), Color(0xFF171C1E)],
          ).createShader(Rect.fromCircle(center: center, radius: 43)),
      );
      for (var dx = -105.0; dx <= 105; dx += 9) {
        for (var dy = -105.0; dy <= 105; dy += 9) {
          if (dx * dx + dy * dy < 116 * 116) {
            canvas.drawCircle(
              center + Offset(dx, dy),
              1.3,
              Paint()..color = Colors.black54,
            );
          }
        }
      }
    }
    _text(
      canvas,
      'FLUX',
      const Offset(52, 91),
      24,
      const Color(0xFF242C2D),
      weight: FontWeight.w900,
    );
    _text(
      canvas,
      'STEREO CASSETTE RECORDER',
      const Offset(602, 100),
      10,
      const Color(0xFF313C3C),
    );
    final display = RRect.fromRectAndRadius(
      const Rect.fromLTWH(331, 93, 238, 43),
      const Radius.circular(6),
    );
    canvas.drawRRect(display, Paint()..color = const Color(0xFF172B25));
    _text(
      canvas,
      'FM  88  92  96  104  108',
      const Offset(343, 101),
      10,
      const Color(0xFF8EC4A0),
    );
    for (var i = 0; i < 23; i++) {
      final h = playing
          ? 3 + (math.sin(phase * 2 * math.pi + i * .8).abs() * 10)
          : 2.0;
      canvas.drawRect(
        Rect.fromLTWH(343 + i * 9.2, 129 - h, 5, h),
        Paint()
          ..color = i > 18 ? const Color(0xFFE8B36F) : const Color(0xFF8EC4A0),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(deckRect.inflate(7), const Radius.circular(9)),
      Paint()
        ..color = accepting ? const Color(0xFFB8D59F) : const Color(0xFF434E4E),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(deckRect, const Radius.circular(5)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF101A1A), Color(0xFF263331)],
        ).createShader(deckRect),
    );
    _text(
      canvas,
      'AUTO STOP • SOFT EJECT',
      const Offset(362, 312),
      10,
      const Color(0xFF222F30),
    );
    for (var i = 0; i < 5; i++) {
      final button = RRect.fromRectAndRadius(
        Rect.fromLTWH(337 + i * 46.0, 340, 40, 33),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        button.shift(const Offset(0, 4)),
        Paint()..color = const Color(0xFF313B3D),
      );
      canvas.drawRRect(
        button,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDBDDD2), Color(0xFF8A9491)],
          ).createShader(button.outerRect),
      );
      _text(
        canvas,
        ['▶', 'Ⅱ', '■', '◀', '⏏'][i],
        Offset(349 + i * 46.0, 347),
        14,
        const Color(0xFF273432),
      );
    }
    for (final point in [
      const Offset(34, 91),
      const Offset(865, 91),
      const Offset(34, 397),
      const Offset(865, 397),
    ]) {
      _screw(canvas, point, 4);
    }
    for (final x in [60.0, 790.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 415, 50, 12),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF111A1C),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BoomboxPainter old) =>
      playing != old.playing ||
      accepting != old.accepting ||
      phase != old.phase;
}
