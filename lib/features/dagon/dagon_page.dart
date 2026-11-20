import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/strings.dart';
import '../../widgets/port_ui/port_ui.dart';

Future<void> openDagon(BuildContext context) =>
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) => const DagonPage(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

class DagonPage extends StatefulWidget {
  const DagonPage({super.key});

  @override
  State<DagonPage> createState() => _DagonPageState();
}

class _DagonPageState extends State<DagonPage> {
  int _level = 1;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF10090B),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Semantics(
                  label: S.flashlightClose,
                  child: PortIconButton.ghost(
                    icon: const Icon(
                      LucideIcons.arrowLeft,
                      color: Color(0xFFFAFAFA),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  S.dagonTitle,
                  style: PortText.large.copyWith(
                    color: const Color(0xFFFAFAFA),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'DAGON',
                            style: PortText.h4.copyWith(
                              fontSize: 36,
                              letterSpacing: 8,
                              color: const Color(0xFFFAFAFA),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            S.dagonLevel(_level),
                            style: PortText.muted.copyWith(
                              color: const Color(0xFFFDA4AF),
                            ),
                          ),
                          const SizedBox(height: 28),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF9F3045),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFEF294E,
                                    ).withValues(alpha: .12 + _level * .035),
                                    blurRadius: 70,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: AspectRatio(
                                  aspectRatio: 88 / 64,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    child: Image.asset(
                                      'assets/rofl/dagon_$_level.png',
                                      key: ValueKey(_level),
                                      semanticLabel: S.dagonLevel(_level),
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var level = 1; level <= 5; level++)
                                Semantics(
                                  label: S.dagonLevel(level),
                                  selected: _level == level,
                                  child: _level == level
                                      ? PortButton(
                                          onPressed: () =>
                                              setState(() => _level = level),
                                          child: Text('$level'),
                                        )
                                      : PortButton.outline(
                                          onPressed: () =>
                                              setState(() => _level = level),
                                          child: Text('$level'),
                                        ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            S.dagonCaption,
                            textAlign: TextAlign.center,
                            style: PortText.muted.copyWith(
                              color: const Color(0xFFA58D94),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Dota 2 · Valve',
                            style: TextStyle(
                              color: Color(0xFF735D64),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
