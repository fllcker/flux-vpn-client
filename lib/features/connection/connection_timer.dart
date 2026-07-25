import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../widgets/port_ui/port_ui.dart';

/// Секундомер времени подключения — как в Happ. Просто перерисовывается
/// раз в секунду, само время идёт от [connectedAt], не от локального
/// счётчика тиков (переживает пропущенные кадры/фоновую паузу).
class ConnectionTimer extends StatefulWidget {
  final DateTime connectedAt;

  const ConnectionTimer({super.key, required this.connectedAt});

  @override
  State<ConnectionTimer> createState() => _ConnectionTimerState();
}

class _ConnectionTimerState extends State<ConnectionTimer> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.connectedAt);
    return Text(_format(elapsed), style: PortText.muted.copyWith(height: 1));
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = two(d.inHours);
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
}
