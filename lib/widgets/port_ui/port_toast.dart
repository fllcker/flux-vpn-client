part of 'port_ui.dart';

/// Toast — sonner.tsx только темизирует внешний npm-пакет `sonner`, логики
/// стекинга/анимации в самом shadcn-ui/ui нет (см. docs/shadcn/PLAN.md).
/// Портирована карточка (bg=popover, border, radius=var(--radius) напрямую,
/// т.е. БЕЗ *0.8) и вход снизу вверх. Стекинг — простой список, без
/// offset/scale эффектов настоящего sonner.
class PortToast {
  final Widget title;
  final Widget? description;
  final bool destructive;

  const PortToast({required this.title, this.description}) : destructive = false;
  const PortToast.destructive({required this.title, this.description}) : destructive = true;
}

/// `PortToaster.of(context).show(...)` — тот же паттерн, что был у
/// `ShadToaster.of(context).show(...)`.
class PortToaster {
  final BuildContext _context;
  const PortToaster._(this._context);

  static PortToaster of(BuildContext context) => PortToaster._(context);

  void show(PortToast toast) =>
      _context.findAncestorStateOfType<_PortToastHostState>()!.show(toast);
}

class PortToastHost extends StatefulWidget {
  final Widget child;
  const PortToastHost({super.key, required this.child});

  @override
  State<PortToastHost> createState() => _PortToastHostState();
}

class _PortToastHostState extends State<PortToastHost> {
  final List<_ToastEntry> _toasts = [];

  void show(PortToast toast) {
    final entry = _ToastEntry(toast);
    setState(() => _toasts.add(entry));
    entry.timer = Timer(const Duration(seconds: 4), () => _remove(entry));
  }

  void _remove(_ToastEntry entry) {
    entry.timer?.cancel();
    if (mounted) setState(() => _toasts.remove(entry));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in _toasts)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ToastCard(toast: entry.toast, onClose: () => _remove(entry)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToastEntry {
  final PortToast toast;
  Timer? timer;
  _ToastEntry(this.toast);
}

class _ToastCard extends StatefulWidget {
  final PortToast toast;
  final VoidCallback onClose;
  const _ToastCard({required this.toast, required this.onClose});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 250))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: _kEase);
    final borderColor = widget.toast.destructive ? PortColors.destructive : PortColors.border;
    return SlideTransition(
      position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(curved),
      child: FadeTransition(
        opacity: curved,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PortColors.popover,
            borderRadius: BorderRadius.circular(kRadius), // var(--radius) напрямую
            border: Border.all(color: borderColor),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 16, offset: Offset(0, 8))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DefaultTextStyle.merge(
                      style: const TextStyle(color: PortColors.popoverForeground, fontSize: 14, fontWeight: FontWeight.w600),
                      child: widget.toast.title,
                    ),
                    if (widget.toast.description != null) ...[
                      const SizedBox(height: 2),
                      DefaultTextStyle.merge(style: PortText.muted.copyWith(fontSize: 13), child: widget.toast.description!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PortIconButton.ghost(icon: const Icon(Icons.close, size: 14), size: 24, onPressed: widget.onClose),
            ],
          ),
        ),
      ),
    );
  }
}
