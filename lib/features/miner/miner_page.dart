import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/strings.dart';
import 'miner_game.dart';
import 'miner_painter.dart';
import 'miner_store.dart';

Future<void> openMiner(BuildContext context) =>
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) => const MinerPage(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

class MinerPage extends StatefulWidget {
  final MinerStore? store;
  const MinerPage({super.key, this.store});
  @override
  State<MinerPage> createState() => _MinerPageState();
}

class _MinerPageState extends State<MinerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _store = widget.store ?? MinerStore();
  late final _effects = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );
  final _focus = FocusNode();
  MinerGame _game = MinerGame.fresh();
  bool _loading = true, _loadFailed = false, _leaving = false;
  String? _status;
  (int, int)? _hit, _hover;
  Color _hitColor = Colors.white;
  Timer? _debounce;
  Duration _lastKeyTime = Duration.zero;
  Future<bool> _pendingSave = Future.value(true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final game = await _store.load();
      if (!mounted) return;
      setState(() {
        _game = game ?? _game;
        _loading = false;
      });
      _focus.requestFocus();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _status = S.minerLoadError;
        });
      }
    }
  }

  Future<bool> _save() {
    if (_loading || _loadFailed) return Future.value(true);
    final snapshot = _game.toJson();
    _pendingSave = _pendingSave.then((_) async {
      try {
        await _store.save(snapshot);
        if (mounted && _status == S.minerSaveError) {
          setState(() => _status = null);
        }
        return true;
      } catch (_) {
        if (mounted) setState(() => _status = S.minerSaveError);
        return false;
      }
    });
    return _pendingSave;
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    _debounce?.cancel();
    final saved = await _save();
    if (!mounted) return;
    _leaving = false;
    if (saved) Navigator.of(context).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _debounce?.cancel();
      _save();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _effects.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _enabled => !_loading && !_loadFailed && !_leaving;

  void _step(int dx, int dy) {
    if (!_enabled) return;
    final tx = _game.x + dx, ty = _game.y + dy;
    final target =
        tx >= 0 && tx < MinerGame.width && ty >= 0 && ty < MinerGame.height
        ? _game.tile(tx, ty)
        : MineTile.air;
    final action = _game.step(dx, dy);
    setState(() {
      _status = action == MineAction.full
          ? S.minerBagFull
          : _game.y == MinerGame.height - 1
          ? S.minerBottom
          : null;
      _hit = action == MineAction.hit || action == MineAction.mined
          ? (tx, ty)
          : null;
      _hitColor = mineColor(target);
    });
    if (_hit != null) _effects.forward(from: 0);
    if (action != MineAction.blocked && action != MineAction.full) _changed();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => (-1, 0),
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.keyD => (1, 0),
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => (0, -1),
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => (0, 1),
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    if (event is KeyRepeatEvent &&
        event.timeStamp - _lastKeyTime < const Duration(milliseconds: 110)) {
      return KeyEventResult.handled;
    }
    _lastKeyTime = event.timeStamp;
    _step(direction.$1, direction.$2);
    return KeyEventResult.handled;
  }

  void _surface() {
    if (!_enabled) return;
    setState(() {
      _game.surface();
      _hit = null;
      _status = null;
    });
    _changed();
    _focus.requestFocus();
  }

  void _sell() {
    setState(() => _status = S.minerSold(_game.sell()));
    _changed();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE8B865),
        brightness: Brightness.dark,
      ),
    ),
    child: Material(
      color: const Color(0xFF0C1721),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: SafeArea(
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _key,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: S.flashlightClose,
                        onPressed: _leave,
                        icon: const Icon(LucideIcons.arrowLeft),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.minerTitle,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(
                              'FLUX MINING CO.',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 2,
                                color: Color(0xFFD6B57C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.pickaxe,
                        size: 22,
                        color: Color(0xFFE8B865),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 880;
                      final boardHeight =
                          (constraints.maxHeight - (wide ? 80 : 180)).clamp(
                            210.0,
                            560.0,
                          );
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _stat(
                                      LucideIcons.coins,
                                      '${_game.coins}',
                                      const Color(0xFFFFD26B),
                                    ),
                                    _stat(
                                      LucideIcons.backpack,
                                      '${_game.load}/${_game.capacity}',
                                      const Color(0xFFDEA978),
                                    ),
                                    _stat(
                                      LucideIcons.arrowDown,
                                      '${_game.y} ${S.minerMeters}',
                                      const Color(0xFF83D6DD),
                                    ),
                                    _stat(
                                      LucideIcons.trophy,
                                      '${_game.bestDepth} ${S.minerMeters}',
                                      const Color(0xFFB9A6EE),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_status != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      _status!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFFFD26B),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (_loading)
                                  const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: CircularProgressIndicator(),
                                  )
                                else if (_loadFailed)
                                  FilledButton(
                                    onPressed: () {
                                      setState(() {
                                        _game = MinerGame.fresh();
                                        _loadFailed = false;
                                        _status = null;
                                      });
                                      _changed();
                                      _focus.requestFocus();
                                    },
                                    child: Text(S.minerStartOver),
                                  )
                                else if (wide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _board(boardHeight)),
                                      const SizedBox(width: 20),
                                      SizedBox(width: 250, child: _controls()),
                                    ],
                                  )
                                else ...[
                                  _board(boardHeight),
                                  const SizedBox(height: 16),
                                  _controls(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _stat(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF192A36),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 13),
        ),
      ],
    ),
  );

  Widget _board(double height) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final cell = constraints.maxWidth / MinerGame.width;
        final rows = (height / cell).floor().clamp(5, 18);
        final camera = (_game.y - rows ~/ 3).clamp(0, MinerGame.height - rows);
        (int, int) point(Offset local) =>
            ((local.dx / cell).floor(), (local.dy / cell).floor() + camera);
        return MouseRegion(
          cursor: SystemMouseCursors.precise,
          onHover: (event) =>
              setState(() => _hover = point(event.localPosition)),
          onExit: (_) => setState(() => _hover = null),
          child: GestureDetector(
            key: const ValueKey('miner-board'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (event) {
              _focus.requestFocus();
              final (x, y) = point(event.localPosition);
              if ((x - _game.x).abs() + (y - _game.y).abs() == 1) {
                _step(x - _game.x, y - _game.y);
              }
            },
            child: AnimatedBuilder(
              animation: _effects,
              builder: (context, _) => SizedBox(
                width: constraints.maxWidth,
                height: rows * cell,
                child: CustomPaint(
                  painter: MinerPainter(
                    game: _game,
                    camera: camera,
                    rows: rows,
                    animation: _effects.value,
                    hit: _hit,
                    hitColor: _hitColor,
                    hover: _hover,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _controls() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF152532),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF304351)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          S.minerInstructions,
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            color: Color(0xFFA9BBC6),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Column(
            children: [
              _direction(LucideIcons.arrowUp, S.minerUp, 0, -1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _direction(LucideIcons.arrowLeft, S.minerLeft, -1, 0),
                  _direction(LucideIcons.arrowDown, S.minerDown, 0, 1),
                  _direction(LucideIcons.arrowRight, S.minerRight, 1, 0),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _enabled && !_game.atSurface ? _surface : null,
          icon: const Icon(LucideIcons.arrowUpToLine, size: 16),
          label: Text(S.minerSurface),
        ),
        FilledButton.icon(
          onPressed: _enabled && _game.atSurface && _game.load > 0
              ? _sell
              : null,
          icon: const Icon(LucideIcons.coins, size: 16),
          label: Text(S.minerSell(_game.cargoValue)),
        ),
        const SizedBox(height: 12),
        Text(S.minerShop, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (!_game.atSurface)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              S.minerSurfaceOnly,
              style: const TextStyle(fontSize: 11, color: Color(0xFFA9BBC6)),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed:
              _enabled &&
                  _game.atSurface &&
                  _game.pickLevel < 5 &&
                  _game.coins >= _game.pickCost
              ? () {
                  setState(() {
                    _game.upgradePick();
                  });
                  _changed();
                  _focus.requestFocus();
                }
              : null,
          child: Text(
            S.minerPick(
              _game.pickLevel + 1,
              _game.pickLevel >= 5 ? 'MAX' : '${_game.pickCost}',
            ),
          ),
        ),
        OutlinedButton(
          onPressed:
              _enabled &&
                  _game.atSurface &&
                  _game.bagLevel < 5 &&
                  _game.coins >= _game.bagCost
              ? () {
                  setState(() {
                    _game.upgradeBag();
                  });
                  _changed();
                  _focus.requestFocus();
                }
              : null,
          child: Text(
            S.minerBag(
              _game.capacity,
              _game.bagLevel >= 5 ? 'MAX' : '${_game.bagCost}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final tile in MineTile.values.where((t) => t.ore))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 9, height: 9, color: mineColor(tile)),
                  const SizedBox(width: 5),
                  Text(
                    '${S.minerOre(tile.index)} · ${tile.price}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFA9BBC6),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: _enabled && _game.atSurface
              ? () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(S.minerNewShaft),
                      content: Text(S.minerNewShaftHint),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(S.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(S.minerNewShaft),
                        ),
                      ],
                    ),
                  );
                  if (yes == true && mounted) {
                    setState(() {
                      _game.newShaft();
                      _hit = null;
                      _status = null;
                    });
                    _changed();
                    _focus.requestFocus();
                  }
                }
              : null,
          child: Text(S.minerNewShaft),
        ),
      ],
    ),
  );

  Widget _direction(IconData icon, String label, int dx, int dy) =>
      IconButton.filledTonal(
        tooltip: label,
        onPressed: _enabled
            ? () {
                _step(dx, dy);
                _focus.requestFocus();
              }
            : null,
        icon: Icon(icon, size: 18),
      );
}
