import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Полноэкранный фон на fragment-шейдере (`uSize: vec2`, `uTime: float` —
/// уровень 0 и 1 float-юниформов соответственно) — общая обвязка для
/// прототипов вроде "Color Bends"/"Simple Gradient"/"Galaxy". См.
/// ROADMAP.md, "Фон — шейдерные эффекты".
class ShaderBackground extends StatefulWidget {
  final String assetPath;

  const ShaderBackground({super.key, required this.assetPath});

  @override
  State<ShaderBackground> createState() => _ShaderBackgroundState();
}

class _ShaderBackgroundState extends State<ShaderBackground>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((elapsed) => setState(() => _elapsed = elapsed))
      ..start();
  }

  @override
  void didUpdateWidget(covariant ShaderBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) _loadShader();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset(widget.assetPath);
    if (mounted) setState(() => _program = program);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    if (program == null) return const SizedBox.shrink();

    return CustomPaint(
      size: Size.infinite,
      painter: _ShaderPainter(
        program: program,
        timeSeconds: _elapsed.inMicroseconds / Duration.microsecondsPerSecond,
      ),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double timeSeconds;

  _ShaderPainter({required this.program, required this.timeSeconds});

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, timeSeconds);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter oldDelegate) =>
      oldDelegate.timeSeconds != timeSeconds ||
      oldDelegate.program != program;
}
