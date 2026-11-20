import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

abstract class TapeAudio extends ChangeNotifier {
  bool get playing;
  Duration get position;
  Duration get duration;
  String? get error;
  Future<void> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> unload();
}

class TapePlayer extends TapeAudio {
  VideoPlayerController? _controller;
  int _generation = 0;
  bool _disposed = false;
  double _volume = .7;
  @override
  bool get playing => _controller?.value.isPlaying ?? false;
  @override
  Duration get position => _controller?.value.position ?? Duration.zero;
  @override
  Duration get duration => _controller?.value.duration ?? Duration.zero;
  @override
  String? get error => _controller?.value.errorDescription;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> load(String path) async {
    await unload();
    if (_disposed) return;
    final generation = _generation;
    final controller = VideoPlayerController.file(File(path));
    _controller = controller;
    controller.addListener(_changed);
    await controller.initialize();
    if (_disposed || generation != _generation) return;
    await controller.setVolume(_volume);
    _changed();
  }

  @override
  Future<void> play() async {
    final controller = _controller;
    if (controller == null) return;
    if (position >= duration) await controller.seekTo(Duration.zero);
    await controller.play();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _controller?.seekTo(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _controller?.setVolume(volume);
  }

  @override
  Future<void> unload() async {
    _generation++;
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_changed);
    await controller?.dispose();
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    unload();
    super.dispose();
  }
}
