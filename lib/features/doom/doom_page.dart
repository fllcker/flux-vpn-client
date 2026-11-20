import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/strings.dart';
import 'doom_runner.dart';

Future<void> openDoom(BuildContext context) => Navigator.of(context).push<void>(
  PageRouteBuilder(
    pageBuilder: (_, animation, secondaryAnimation) => const DoomPage(),
    transitionsBuilder: (_, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  ),
);

class DoomPage extends StatefulWidget {
  final DoomRunner? runner;
  const DoomPage({super.key, this.runner});
  @override
  State<DoomPage> createState() => _DoomPageState();
}

class _DoomPageState extends State<DoomPage> {
  late final _runner = widget.runner ?? DoomRunner.instance;
  bool _custom = false;
  bool _importing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _runner.addListener(_changed);
    _runner.refresh();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _import() async {
    if (_importing || _runner.running || _runner.starting) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['wad'],
      );
      if (file?.path == null) return;
      await _runner.importWad(file!.path!);
      if (mounted) setState(() => _custom = true);
    } on FormatException {
      if (mounted) setState(() => _error = S.doomInvalidWad);
    } catch (_) {
      if (mounted) setState(() => _error = S.doomImportError);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  void dispose() {
    _runner.removeListener(_changed);
    // The game can continue while the user returns to the VPN screen.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy =
        _importing || _runner.loading || _runner.starting || _runner.running;
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6E36),
          brightness: Brightness.dark,
        ),
      ),
      child: Material(
        color: const Color(0xFF100D0B),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: S.flashlightClose,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(LucideIcons.arrowLeft),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'DOOM',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    const Text(
                      'FLUX ARCADE',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2,
                        color: Color(0xFFBF8D66),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Positioned.fill(
                                  child: CustomPaint(painter: _DoomBackdrop()),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'DOOM',
                                        style: TextStyle(
                                          fontSize: 86,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -5,
                                          color: const Color(0xFFE9BD78),
                                          shadows: [
                                            const Shadow(
                                              color: Color(0xFF371409),
                                              offset: Offset(0, 6),
                                            ),
                                            Shadow(
                                              color: const Color(
                                                0xFFFF5421,
                                              ).withValues(alpha: .4),
                                              blurRadius: 35,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Text(
                                        S.doomTagline,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFFC7A07C),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            S.doomCampaign,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFAA8E73),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Freedoom: Phase 1'),
                                selected: !_custom,
                                onSelected: busy
                                    ? null
                                    : (_) => setState(() => _custom = false),
                              ),
                              if (_runner.customTitle != null)
                                ChoiceChip(
                                  label: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 220,
                                    ),
                                    child: Text(
                                      _runner.customTitle!,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  selected: _custom,
                                  onSelected: busy
                                      ? null
                                      : (_) => setState(() => _custom = true),
                                ),
                              OutlinedButton.icon(
                                onPressed: busy || !_runner.supported
                                    ? null
                                    : _import,
                                icon: const Icon(
                                  LucideIcons.folderOpen,
                                  size: 16,
                                ),
                                label: Text(S.doomOwnWad),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            S.doomDescription,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFBBAC9B),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_error != null || _runner.failed) ...[
                            Text(
                              _error ?? S.doomLaunchError,
                              style: const TextStyle(color: Color(0xFFFFB4AB)),
                            ),
                            const SizedBox(height: 12),
                          ],
                          FilledButton.icon(
                            key: const ValueKey('launch-doom'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 56),
                              backgroundColor: const Color(0xFFDB592E),
                              foregroundColor: Colors.white,
                            ),
                            onPressed:
                                busy || !_runner.available || !_runner.supported
                                ? null
                                : () => _runner.launch(custom: _custom),
                            icon: Icon(
                              _runner.running
                                  ? LucideIcons.gamepad2
                                  : LucideIcons.play,
                              size: 20,
                            ),
                            label: Text(
                              _runner.running
                                  ? S.doomRunning
                                  : _runner.starting || _runner.loading
                                  ? S.doomStarting
                                  : S.doomPlay,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            !_runner.supported
                                ? S.doomWindowsOnly
                                : !_runner.available && !_runner.loading
                                ? S.doomNotInstalled
                                : _runner.running
                                ? S.doomRunningHint
                                : S.doomWindowHint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFAA8E73),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF211C17),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF473329),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  S.doomControls,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 28,
                                  runSpacing: 16,
                                  children: [
                                    _control('↑ ↓ ← →', S.doomMove),
                                    _control('Ctrl / LMB', S.doomFire),
                                    _control('Space', S.doomUse),
                                    _control('1–7', S.doomWeapon),
                                    _control('Esc', S.doomMenu),
                                    _control('F2 / F3', S.doomSaveLoad),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  S.doomControlsHint,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFAA8E73),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Crispy Doom 7.2.0 · Freedoom 0.13.0',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF806A57),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _control(String keys, String label) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          keys,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFFF0B282),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFFBBAC9B)),
        ),
      ],
    ),
  );
}

class _DoomBackdrop extends CustomPainter {
  const _DoomBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF6B2D16), Color(0xFF100D0B)],
          radius: .8,
        ).createShader(Offset.zero & size),
    );
    final vanishing = Offset(size.width / 2, size.height * .4);
    for (var i = 0; i < 8; i++) {
      final inset = i * size.width * .055;
      final rect = Rect.fromLTRB(
        inset,
        i * 8,
        size.width - inset,
        size.height - i * 8,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF925333).withValues(alpha: .12),
      );
    }
    for (var i = 0; i <= 10; i++) {
      canvas.drawLine(
        vanishing,
        Offset(size.width * i / 10, size.height),
        Paint()..color = const Color(0xFF925333).withValues(alpha: .15),
      );
    }
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = Colors.black.withValues(alpha: .12),
      );
    }
  }

  @override
  bool shouldRepaint(_DoomBackdrop oldDelegate) => false;
}
