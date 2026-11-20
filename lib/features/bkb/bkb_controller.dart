import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

class BkbController extends ChangeNotifier {
  static final instance = BkbController();
  final bool desktop;
  final Future<bool> Function() _isMaximized;
  final Future<Rect> Function() _getBounds;
  final Future<void> Function() _maximize;
  final Future<void> Function() _unmaximize;
  final Future<void> Function(Rect) _setBounds;
  bool active = false;
  int remainingSeconds = 0;
  bool restoreFailed = false;
  bool _disposed = false;
  Timer? _timer;
  bool busy = false;
  bool _wasMaximized = false;
  Rect? _bounds;

  BkbController({
    bool? desktop,
    Future<bool> Function()? isMaximized,
    Future<Rect> Function()? getBounds,
    Future<void> Function()? maximize,
    Future<void> Function()? unmaximize,
    Future<void> Function(Rect)? setBounds,
  }) : desktop = desktop ?? (Platform.isWindows || Platform.isMacOS),
       _isMaximized = isMaximized ?? windowManager.isMaximized,
       _getBounds = getBounds ?? windowManager.getBounds,
       _maximize = maximize ?? (() => windowManager.maximize()),
       _unmaximize = unmaximize ?? windowManager.unmaximize,
       _setBounds =
           setBounds ??
           ((rect) => windowManager.setBounds(rect, animate: true));

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> activate() async {
    if (busy || active || _disposed) return true;
    busy = true;
    restoreFailed = false;
    _changed();
    try {
      if (desktop) {
        _wasMaximized = await _isMaximized();
        _bounds = _wasMaximized ? null : await _getBounds();
        await _maximize();
      }
      if (_disposed) return false;
      active = true;
      remainingSeconds = 8;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        remainingSeconds = (8 - timer.tick).clamp(0, 8);
        if (remainingSeconds == 0) {
          timer.cancel();
          _timer = null;
          unawaited(_expire());
        } else {
          _changed();
        }
      });
      return true;
    } catch (_) {
      return false;
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> _expire() async {
    active = false;
    busy = true;
    _changed();
    try {
      if (desktop) {
        if (_wasMaximized) {
          await _maximize();
        } else {
          await _unmaximize();
          if (_bounds != null) await _setBounds(_bounds!);
        }
      }
    } catch (_) {
      restoreFailed = true;
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
