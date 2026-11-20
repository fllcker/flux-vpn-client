import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/strings.dart';

Future<void> openFlashlight(BuildContext context) =>
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) =>
            const FlashlightPage(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

class FlashlightPage extends StatefulWidget {
  const FlashlightPage({super.key});

  @override
  State<FlashlightPage> createState() => _FlashlightPageState();
}

class _FlashlightPageState extends State<FlashlightPage> {
  bool _on = true;
  bool _screen = false;
  bool _draggingBeam = false;
  double _brightness = .8;
  double _length = .65;
  double _width = .55;
  static const _mint = Color(0xFFA7F3D0);

  @override
  Widget build(BuildContext context) {
    final distance = (1 + math.pow(_length, 4) * 11999).round();
    return Theme(
      data: ThemeData.dark().copyWith(
        sliderTheme: const SliderThemeData(
          activeTrackColor: _mint,
          thumbColor: _mint,
          inactiveTrackColor: Color(0xFF283832),
        ),
      ),
      child: Material(
        color: _screen && _on
            ? Color.lerp(const Color(0xFF202020), Colors.white, _brightness)
            : const Color(0xFF070C0A),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_screen) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.sun,
                        color: Colors.black54,
                        size: 44,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.tonal(
                        onPressed: () => setState(() => _screen = false),
                        child: Text(S.flashlightBackToBeam),
                      ),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                physics: _draggingBeam
                    ? const NeverScrollableScrollPhysics()
                    : null,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: S.flashlightClose,
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(LucideIcons.arrowLeft),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  S.flashlightTitle,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Text(
                                'FLUX LAB',
                                style: TextStyle(
                                  color: _mint,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            S.flashlightSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Listener(
                            key: const ValueKey('beam-gesture'),
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (_) =>
                                setState(() => _draggingBeam = true),
                            onPointerUp: (_) =>
                                setState(() => _draggingBeam = false),
                            onPointerCancel: (_) =>
                                setState(() => _draggingBeam = false),
                            onPointerMove: (details) => setState(() {
                              _width = (_width + details.delta.dx / 220).clamp(
                                0,
                                1,
                              );
                              _length = (_length - details.delta.dy / 220)
                                  .clamp(0, 1);
                            }),
                            child: SizedBox(
                              width: double.infinity,
                              height: (constraints.maxHeight * .36).clamp(
                                150,
                                330,
                              ),
                              child: CustomPaint(
                                painter: FlashlightBeamPainter(
                                  brightness: _on ? _brightness : 0,
                                  length: _length,
                                  width: _width,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            _on
                                ? '$distance ${S.flashlightKm}'
                                : S.flashlightOff,
                            style: const TextStyle(
                              color: _mint,
                              fontSize: 30,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            S.flashlightDistanceHint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111B16),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              children: [
                                _slider(
                                  S.flashlightBrightness,
                                  LucideIcons.sun,
                                  _brightness,
                                  '${(_brightness * 100).round()}%',
                                  (value) =>
                                      setState(() => _brightness = value),
                                ),
                                _slider(
                                  S.flashlightLength,
                                  LucideIcons.moveVertical,
                                  _length,
                                  _length > .9
                                      ? S.flashlightOrbital
                                      : S.flashlightHighBeam,
                                  (value) => setState(() => _length = value),
                                ),
                                _slider(
                                  S.flashlightWidth,
                                  LucideIcons.moveHorizontal,
                                  _width,
                                  '${(8 + _width * 72).round()}°',
                                  (value) => setState(() => _width = value),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 20,
                            runSpacing: 12,
                            children: [
                              Semantics(
                                label: S.flashlightPower,
                                toggled: _on,
                                child: IconButton.filled(
                                  key: const ValueKey('flashlight-power'),
                                  style: IconButton.styleFrom(
                                    backgroundColor: _on
                                        ? _mint
                                        : const Color(0xFF25352C),
                                    foregroundColor: _on
                                        ? Colors.black
                                        : Colors.white,
                                    minimumSize: const Size(64, 64),
                                  ),
                                  onPressed: () => setState(() => _on = !_on),
                                  icon: const Icon(LucideIcons.power, size: 28),
                                ),
                              ),
                              const SizedBox(width: 20),
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _on = true;
                                  _screen = true;
                                }),
                                icon: const Icon(LucideIcons.monitor, size: 18),
                                label: Text(S.flashlightScreen),
                                style: TextButton.styleFrom(
                                  foregroundColor: _mint,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            S.flashlightGestureHint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    IconData icon,
    double value,
    String detail,
    ValueChanged<double> onChanged,
  ) => Column(
    children: [
      Row(
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
          Text(detail, style: const TextStyle(fontSize: 11, color: _mint)),
        ],
      ),
      SizedBox(
        height: 34,
        child: Slider(
          value: value,
          onChanged: onChanged,
          semanticFormatterCallback: (v) => '$label: ${(v * 100).round()}%',
        ),
      ),
    ],
  );
}

class FlashlightBeamPainter extends CustomPainter {
  final double brightness;
  final double length;
  final double width;

  const FlashlightBeamPainter({
    required this.brightness,
    required this.length,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height - 30);
    final reach = (size.height - 48) * (.22 + length * .78);
    final spread = math.min(size.width * .46, 18 + width * size.width * .42);
    final tipY = origin.dy - reach;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .045)
      ..style = PaintingStyle.stroke;
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(origin, i * size.height / 5, grid);
    }
    if (brightness > 0) {
      final beam = Path()
        ..moveTo(origin.dx - 8, origin.dy)
        ..lineTo(origin.dx - spread, tipY)
        ..quadraticBezierTo(origin.dx, tipY - 22, origin.dx + spread, tipY)
        ..lineTo(origin.dx + 8, origin.dy)
        ..close();
      final bounds = Rect.fromLTRB(
        origin.dx - spread,
        tipY - 22,
        origin.dx + spread,
        origin.dy,
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.white.withValues(alpha: brightness * .95),
            const Color(0xFFC4FFE0).withValues(alpha: brightness * .32),
            const Color(0xFFA7F3D0).withValues(alpha: 0),
          ],
        ).createShader(bounds);
      canvas.drawPath(
        beam,
        Paint()
          ..shader = paint.shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawPath(beam, paint);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(origin.dx, tipY),
          width: spread * 2,
          height: 18,
        ),
        Paint()
          ..color = const Color(0xFFA7F3D0).withValues(alpha: brightness * .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: origin + const Offset(0, 12),
        width: 34,
        height: 42,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF33463A), Color(0xFF18241D), Color(0xFF405448)],
        ).createShader(body.outerRect),
    );
    canvas.drawOval(
      Rect.fromCenter(center: origin, width: 30, height: 9),
      Paint()
        ..color = brightness > 0
            ? Colors.white.withValues(alpha: .3 + brightness * .7)
            : const Color(0xFF536059),
    );
  }

  @override
  bool shouldRepaint(FlashlightBeamPainter oldDelegate) =>
      brightness != oldDelegate.brightness ||
      length != oldDelegate.length ||
      width != oldDelegate.width;
}
