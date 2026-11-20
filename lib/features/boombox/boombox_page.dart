import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/strings.dart';
import 'boombox_art.dart';
import 'tape_library.dart';
import 'tape_player.dart';

Future<void> openBoombox(BuildContext context) =>
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) => const BoomboxPage(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

class BoomboxPage extends StatefulWidget {
  final TapeLibrary? library;
  final TapeAudio? audio;
  const BoomboxPage({super.key, this.library, this.audio});

  @override
  State<BoomboxPage> createState() => _BoomboxPageState();
}

class _BoomboxPageState extends State<BoomboxPage>
    with SingleTickerProviderStateMixin {
  late final _library = widget.library ?? TapeLibrary();
  late final _audio = widget.audio ?? TapePlayer();
  late final _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  List<Tape> _tapes = [];
  Tape? _inserted;
  bool _busy = false;
  bool _importing = false;
  bool _loading = true;
  bool _ready = false;
  String? _error;
  double _volume = .7;

  @override
  void initState() {
    super.initState();
    _audio.addListener(_audioChanged);
    _loadLibrary();
  }

  void _audioChanged() {
    if (!mounted) return;
    if (_audio.playing && !_rotation.isAnimating) _rotation.repeat();
    if (!_audio.playing && _rotation.isAnimating) _rotation.stop();
    setState(() {});
  }

  Future<void> _loadLibrary() async {
    try {
      final tapes = await _library.load();
      if (mounted) {
        setState(() {
          _tapes = tapes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = S.tapeLibraryError;
          _loading = false;
        });
      }
    }
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    var failed = 0;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
      );
      for (final file in result?.files ?? <PlatformFile>[]) {
        if (file.path == null) {
          failed++;
          continue;
        }
        try {
          final tape = await _library.importMp3(file.path!);
          if (mounted) setState(() => _tapes = [..._tapes, tape]);
        } catch (_) {
          failed++;
        }
      }
      if (failed > 0 && mounted) setState(() => _error = S.tapeImportError);
    } catch (_) {
      if (mounted) setState(() => _error = S.tapeImportError);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _insert(Tape tape) async {
    if (_busy || _inserted?.id == tape.id) return;
    setState(() {
      _busy = true;
      _ready = false;
      _inserted = tape;
      _error = null;
    });
    try {
      await _audio.load(tape.path);
      if (!mounted) return;
      await _audio.setVolume(_volume);
      await _audio.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = S.tapePlaybackError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _eject() async {
    if (_busy || _inserted == null) return;
    setState(() {
      _busy = true;
      _ready = false;
      _inserted = null;
      _error = null;
    });
    try {
      await _audio.unload();
    } catch (_) {
      if (mounted) setState(() => _error = S.tapePlaybackError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _command(Future<void> Function() action) async {
    if (_busy || !_ready) return;
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _error = S.tapePlaybackError);
    }
  }

  @override
  void dispose() {
    _audio.removeListener(_audioChanged);
    _audio.dispose();
    _rotation.dispose();
    super.dispose();
  }

  String _time(Duration value) =>
      '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE5AE72),
        brightness: Brightness.dark,
      ),
    ),
    child: Material(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-.3, -.4),
            radius: 1.4,
            colors: [Color(0xFF46514B), Color(0xFF171F23), Color(0xFF101719)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: S.flashlightClose,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(LucideIcons.arrowLeft),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.boomboxTitle,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'FLUX AUDIO LAB / 1986',
                            style: TextStyle(
                              color: Color(0xFFBDA584),
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null || _audio.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _error ?? S.tapePlaybackError,
                    style: const TextStyle(color: Color(0xFFFFB4AB)),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1000;
                    final player = _player();
                    final shelf = _shelf();
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 7, child: player),
                                    const SizedBox(width: 32),
                                    Expanded(flex: 3, child: shelf),
                                  ],
                                )
                              : Column(
                                  children: [
                                    player,
                                    const SizedBox(height: 24),
                                    shelf,
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
  );

  Widget _player() => Column(
    children: [
      const SizedBox(height: 8),
      Text(
        S.tapeSubtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFC8C5B6), fontSize: 13),
      ),
      const SizedBox(height: 8),
      DragTarget<Tape>(
        key: const ValueKey('cassette-deck'),
        onWillAcceptWithDetails: (details) =>
            !_busy && details.data.id != _inserted?.id,
        onAcceptWithDetails: (details) => _insert(details.data),
        builder: (context, candidates, rejected) => LayoutBuilder(
          builder: (context, constraints) {
            final scale = constraints.maxWidth / 900;
            return SizedBox(
              height: 450 * scale,
              child: AnimatedBuilder(
                animation: _rotation,
                builder: (context, _) => Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: BoomboxPainter(
                          playing: _audio.playing,
                          accepting: candidates.isNotEmpty,
                          phase: _rotation.value,
                        ),
                      ),
                    ),
                    Positioned(
                      left: deckRect.left * scale,
                      top: deckRect.top * scale,
                      width: deckRect.width * scale,
                      height: deckRect.height * scale,
                      child: _inserted == null
                          ? Center(
                              child: Icon(
                                LucideIcons.disc3,
                                size: 40 * scale,
                                color: Colors.white24,
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.all(6 * scale),
                              child: _draggable(_inserted!, inDeck: true),
                            ),
                    ),
                    for (var index = 0; index < 5; index++)
                      Positioned(
                        left: (337 + index * 46) * scale,
                        top: 340 * scale,
                        width: 40 * scale,
                        height: 33 * scale,
                        child: Tooltip(
                          message: [
                            S.tapePlay,
                            S.tapePause,
                            S.tapeStop,
                            S.tapeRewind,
                            S.tapeEject,
                          ][index],
                          child: Semantics(
                            label: [
                              S.tapePlay,
                              S.tapePause,
                              S.tapeStop,
                              S.tapeRewind,
                              S.tapeEject,
                            ][index],
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _busy ? null : () => _transport(index),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF121E1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF40514A)),
        ),
        child: Column(
          children: [
            Text(
              _inserted?.title ?? S.tapeEmptyDeck,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFCCE3B3),
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _busy
                  ? S.tapeLoading
                  : '${_time(_audio.position)} / ${_time(_audio.duration)}',
              style: const TextStyle(
                color: Color(0xFF8AA083),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            Slider(
              value: _audio.duration.inMilliseconds <= 0
                  ? 0
                  : (_audio.position.inMilliseconds /
                            _audio.duration.inMilliseconds)
                        .clamp(0, 1),
              onChanged: !_ready || _busy
                  ? null
                  : (v) => _command(
                      () => _audio.seek(
                        Duration(
                          milliseconds: (_audio.duration.inMilliseconds * v)
                              .round(),
                        ),
                      ),
                    ),
              semanticFormatterCallback: (v) => _time(
                Duration(
                  milliseconds: (_audio.duration.inMilliseconds * v).round(),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          IconButton(
            tooltip: _audio.playing ? S.tapePause : S.tapePlay,
            onPressed: !_ready || _busy
                ? null
                : () => _command(_audio.playing ? _audio.pause : _audio.play),
            icon: Icon(_audio.playing ? LucideIcons.pause : LucideIcons.play),
          ),
          IconButton(
            tooltip: S.tapeStop,
            onPressed: !_ready || _busy ? null : () => _transport(2),
            icon: const Icon(LucideIcons.square),
          ),
          IconButton(
            tooltip: S.tapeEject,
            onPressed: _inserted == null || _busy ? null : _eject,
            icon: const Icon(Icons.eject),
          ),
        ],
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Row(
          children: [
            const Icon(LucideIcons.volume2, size: 18, color: Color(0xFFBDA584)),
            Expanded(
              child: Slider(
                value: _volume,
                onChanged: (v) {
                  setState(() => _volume = v);
                  _setVolume(v);
                },
                semanticFormatterCallback: (v) =>
                    '${S.tapeVolume}: ${(v * 100).round()}%',
              ),
            ),
            Text(
              '${(_volume * 100).round()}%',
              style: const TextStyle(fontSize: 11, color: Color(0xFFBDA584)),
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _setVolume(double volume) async {
    try {
      await _audio.setVolume(volume);
    } catch (_) {
      if (mounted) setState(() => _error = S.tapePlaybackError);
    }
  }

  void _transport(int index) {
    switch (index) {
      case 0:
        _command(_audio.play);
      case 1:
        _command(_audio.pause);
      case 2:
        _command(() async {
          await _audio.pause();
          await _audio.seek(Duration.zero);
        });
      case 3:
        _command(
          () => _audio.seek(
            Duration(
              milliseconds: math.max(0, _audio.position.inMilliseconds - 10000),
            ),
          ),
        );
      case 4:
        _eject();
    }
  }

  Widget _draggable(Tape tape, {bool inDeck = false}) => Draggable<Tape>(
    data: tape,
    maxSimultaneousDrags: _busy ? 0 : 1,
    feedback: Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 210,
        child: Transform.rotate(angle: -.07, child: CassetteArt(tape: tape)),
      ),
    ),
    childWhenDragging: Opacity(opacity: .15, child: CassetteArt(tape: tape)),
    child: Semantics(
      label: '${tape.title}. ${inDeck ? S.tapeEjectHint : S.tapeInsertHint}',
      child: MouseRegion(
        cursor: _busy ? SystemMouseCursors.wait : SystemMouseCursors.grab,
        child: GestureDetector(
          onTap: inDeck || _busy ? null : () => _insert(tape),
          child: CassetteArt(
            tape: tape,
            rotation: inDeck ? _rotation.value * math.pi * 2 : 0,
          ),
        ),
      ),
    ),
  );

  Widget _shelf() => DragTarget<Tape>(
    key: const ValueKey('cassette-shelf'),
    onWillAcceptWithDetails: (details) =>
        !_busy && details.data.id == _inserted?.id,
    onAcceptWithDetails: (_) => _eject(),
    builder: (context, candidates, rejected) => AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: candidates.isNotEmpty
              ? [const Color(0xFF4D6050), const Color(0xFF29372C)]
              : [const Color(0xFF5B4939), const Color(0xFF302922)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: candidates.isNotEmpty
              ? const Color(0xFFCBE5B0)
              : const Color(0xFF88715B),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.tapeShelf,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE6D5BA),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.tapeShelfHint,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFBCA78C),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _importing || _loading ? null : _import,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: Text(_importing ? S.tapeImporting : S.tapeImport),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_tapes.where((t) => t.id != _inserted?.id).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                _tapes.isEmpty ? S.tapeEmptyShelf : S.tapeReturnHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFBCA78C), fontSize: 12),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = math.max(
                  1,
                  (constraints.maxWidth / 180).floor(),
                );
                final width =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 22,
                  children: [
                    for (final tape in _tapes.where(
                      (t) => t.id != _inserted?.id,
                    ))
                      SizedBox(
                        width: width,
                        child: Column(
                          children: [
                            Transform.rotate(
                              angle: (tape.title.length % 3 - 1) * .02,
                              child: _draggable(tape),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tape.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFD6C3A7),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    ),
  );
}
