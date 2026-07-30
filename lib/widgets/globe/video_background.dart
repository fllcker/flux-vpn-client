import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Полноэкранный фон из видеофайла юзера (`HomeBackground.customVideo`,
/// `AppSettings.customVideoPath`) — лупом, без звука. Аналог
/// `ShaderBackground`, но источник не шейдер, а произвольный видеофайл,
/// который юзер сам выбрал и который был скопирован в аппдату
/// (`custom_video_storage.dart`).
class VideoBackground extends StatefulWidget {
  final String filePath;

  const VideoBackground({super.key, required this.filePath});

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.file(File(widget.filePath));
    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      setState(() => _controller = controller);
    } catch (_) {
      // Файл мог быть удалён/повреждён/в неподдерживаемом формате извне
      // приложения — тихо остаёмся без фона, а не роняем экран подключения.
      controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
