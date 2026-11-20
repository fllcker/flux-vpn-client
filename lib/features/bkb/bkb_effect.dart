import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/strings.dart';
import 'bkb_controller.dart';

class BkbEffect extends StatelessWidget {
  final Widget child;
  final BkbController? controller;
  const BkbEffect({super.key, required this.child, this.controller});

  @override
  Widget build(BuildContext context) {
    final bkb = controller ?? BkbController.instance;
    return ListenableBuilder(
      listenable: bkb,
      builder: (context, _) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: bkb.active ? 1 : 0),
        duration: const Duration(milliseconds: 350),
        builder: (context, intensity, _) {
          const normal = <double>[
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ];
          const gold = <double>[
            .45,
            .45,
            .1,
            0,
            28,
            .36,
            .36,
            .08,
            0,
            16,
            .05,
            .05,
            .02,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ];
          return Stack(
            fit: StackFit.expand,
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.matrix([
                  for (var i = 0; i < 20; i++)
                    normal[i] + (gold[i] - normal[i]) * intensity,
                ]),
                child: child,
              ),
              if (intensity > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(
                            0xFFFFD447,
                          ).withValues(alpha: intensity),
                          width: 5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFFBE1B,
                            ).withValues(alpha: .4 * intensity),
                            blurRadius: 40,
                            spreadRadius: -8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (bkb.active)
                Positioned(
                  left: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF332400),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD447)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.shield,
                          color: Color(0xFFFFD447),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          S.bkbRemaining(bkb.remainingSeconds),
                          style: const TextStyle(
                            color: Color(0xFFFFD447),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
