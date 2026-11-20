import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'miner_game.dart';

Color mineColor(MineTile tile) => const [
  Color(0xFF111E28),
  Color(0xFF785039),
  Color(0xFF53616C),
  Color(0xFF2A3039),
  Color(0xFFDE8B54),
  Color(0xFFFFCC54),
  Color(0xFF6FE2F2),
][tile.index];

class MinerPainter extends CustomPainter {
  final MinerGame game;
  final int camera;
  final int rows;
  final double animation;
  final (int, int)? hit;
  final Color hitColor;
  final (int, int)? hover;
  MinerPainter({
    required this.game,
    required this.camera,
    required this.rows,
    required this.animation,
    this.hit,
    this.hitColor = Colors.white,
    this.hover,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / MinerGame.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101C26),
    );
    for (var sy = 0; sy < rows; sy++) {
      final row = camera + sy;
      if (row >= MinerGame.height) break;
      for (var col = 0; col < MinerGame.width; col++) {
        final tile = game.tile(col, row);
        final rect = Rect.fromLTWH(col * cell, sy * cell, cell, cell);
        final color = mineColor(tile);
        if (row == 0) {
          canvas.drawRect(rect, Paint()..color = const Color(0xFF5A938C));
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left,
              rect.bottom - cell * .15,
              cell,
              cell * .15,
            ),
            Paint()..color = const Color(0xFF8DB969),
          );
          if (col == 7) {
            canvas.drawRect(
              Rect.fromLTWH(
                rect.left + cell * .12,
                rect.top + cell * .23,
                cell * .76,
                cell * .62,
              ),
              Paint()..color = const Color(0xFFC19157),
            );
            canvas.drawRect(
              Rect.fromLTWH(
                rect.left + cell * .38,
                rect.top + cell * .43,
                cell * .26,
                cell * .42,
              ),
              Paint()..color = const Color(0xFF203240),
            );
            canvas.drawPath(
              Path()
                ..moveTo(rect.left + cell * .05, rect.top + cell * .27)
                ..lineTo(rect.center.dx, rect.top + cell * .04)
                ..lineTo(rect.right - cell * .05, rect.top + cell * .27)
                ..close(),
              Paint()..color = const Color(0xFFE8B85B),
            );
          }
          continue;
        }
        if (tile == MineTile.air) {
          // Every excavated cell gets a ladder, so tunnels are traversable upwards.
          final ladder = Paint()
            ..color = const Color(0xFF655644)
            ..strokeWidth = math.max(1, cell * .045);
          for (final fraction in [.32, .68]) {
            canvas.drawLine(
              Offset(rect.left + cell * fraction, rect.top),
              Offset(rect.left + cell * fraction, rect.bottom),
              ladder,
            );
          }
          for (var r = 1; r <= 3; r++) {
            canvas.drawLine(
              Offset(rect.left + cell * .32, rect.top + cell * r / 4),
              Offset(rect.left + cell * .68, rect.top + cell * r / 4),
              ladder,
            );
          }
        } else {
          canvas.drawRect(
            rect.deflate(.5),
            Paint()
              ..color = tile.ore
                  ? Color.lerp(mineColor(MineTile.stone), color, .16)!
                  : color,
          );
          canvas.drawRect(
            Rect.fromLTWH(rect.left + 1, rect.top + 1, cell - 2, cell * .07),
            Paint()..color = Colors.white.withValues(alpha: .08),
          );
          final noise = (col * 17 + row * 31 + game.seed) % 9;
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left + cell * (.14 + noise * .05),
              rect.top + cell * .64,
              cell * .23,
              cell * .07,
            ),
            Paint()..color = Colors.black.withValues(alpha: .18),
          );
          if (tile.ore) {
            for (var chunk = 0; chunk < 4; chunk++) {
              final x =
                  rect.left + cell * (.2 + ((chunk * 3 + noise) % 6) * .1);
              final y =
                  rect.top + cell * (.2 + ((chunk * 2 + noise) % 5) * .13);
              final rock = Rect.fromLTWH(x, y, cell * .16, cell * .18);
              canvas.drawRect(
                rock.shift(Offset(0, cell * .04)),
                Paint()..color = Colors.black38,
              );
              canvas.drawRect(rock, Paint()..color = color);
              canvas.drawRect(
                Rect.fromLTWH(x, y, cell * .07, cell * .06),
                Paint()..color = Color.lerp(color, Colors.white, .55)!,
              );
            }
          }
          final damage = game.damage[game.index(col, row)] ?? 0;
          if (damage > 0) {
            canvas.drawPath(
              Path()
                ..moveTo(rect.left + cell * .2, rect.top)
                ..lineTo(rect.center.dx, rect.center.dy)
                ..lineTo(rect.left + cell * .3, rect.bottom)
                ..moveTo(rect.center.dx, rect.center.dy)
                ..lineTo(rect.right, rect.top + cell * .3),
              Paint()
                ..style = PaintingStyle.stroke
                ..color = const Color(0xFF14202A)
                ..strokeWidth = 2,
            );
            canvas.drawRect(
              Rect.fromLTWH(
                rect.left + 2,
                rect.bottom - 4,
                (cell - 4) * damage / tile.hardness,
                2,
              ),
              Paint()..color = const Color(0xFFF5C65B),
            );
          }
        }
        final distance = math.sqrt(
          math.pow(col - game.x, 2) + math.pow(row - game.y, 2),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = const Color(
              0xFF060D17,
            ).withValues(alpha: (distance / 12).clamp(0, .68)),
        );
      }
    }
    if (hover case (
      final col,
      final row,
    ) when (col - game.x).abs() + (row - game.y).abs() == 1) {
      canvas.drawRect(
        Rect.fromLTWH(
          col * cell + 1,
          (row - camera) * cell + 1,
          cell - 2,
          cell - 2,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFD26B),
      );
    }
    final px = (game.x + .5) * cell, py = (game.y - camera + .5) * cell;
    canvas.save();
    canvas.translate(px, py);
    canvas.scale(cell / 32);
    canvas.drawOval(
      const Rect.fromLTWH(-9, 9, 18, 5),
      Paint()..color = Colors.black45,
    );
    canvas.drawRect(
      const Rect.fromLTWH(-7, -3, 14, 12),
      Paint()..color = const Color(0xFF59A9BD),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-8, -1, 5, 10),
      Paint()..color = const Color(0xFFBD754C),
    );
    for (final x in [-6.0, 2.0]) {
      canvas.drawRect(
        Rect.fromLTWH(x, 8, 5, 5),
        Paint()..color = const Color(0xFF1D2E42),
      );
      canvas.drawRect(
        Rect.fromLTWH(x - 1, 12, 7, 3),
        Paint()..color = const Color(0xFF101B28),
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(-6, -11, 12, 10),
      Paint()..color = const Color(0xFFF0B58B),
    );
    canvas.drawRect(
      const Rect.fromLTWH(2, -8, 2, 2),
      Paint()..color = const Color(0xFF172532),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-8, -14, 16, 6),
      Paint()..color = const Color(0xFFEABD4F),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-10, -9, 21, 3),
      Paint()..color = const Color(0xFFFFD76F),
    );
    canvas.drawCircle(
      const Offset(6, -11),
      3,
      Paint()..color = const Color(0xFFFFF4C6),
    );
    canvas.drawCircle(
      const Offset(6, -11),
      5,
      Paint()..color = const Color(0xFFFFE1A1).withValues(alpha: .18),
    );
    canvas.save();
    canvas.translate(9, 2);
    if (hit != null && animation < 1) {
      canvas.rotate(-math.sin(animation * math.pi) * 1.2);
    }
    canvas.drawLine(
      const Offset(0, 6),
      const Offset(8, -6),
      Paint()
        ..color = const Color(0xFFB0804D)
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      const Offset(3, -10),
      const Offset(14, -3),
      Paint()
        ..color = const Color(0xFFCCE2E7)
        ..strokeWidth = 3,
    );
    canvas.restore();
    canvas.restore();
    if (hit case (final hx, final hy) when animation < 1) {
      for (var i = 0; i < 9; i++) {
        final a = i * 2.4;
        final travel = cell * animation * (i.isEven ? .8 : 1.2);
        final center = Offset(
          (hx + .5) * cell + math.cos(a) * travel,
          (hy - camera + .5) * cell +
              math.sin(a) * travel +
              cell * animation * animation * .4,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: center,
            width: cell * .09,
            height: cell * .09,
          ),
          Paint()..color = hitColor.withValues(alpha: 1 - animation),
        );
      }
    }
  }

  @override
  bool shouldRepaint(MinerPainter oldDelegate) => true;
}
