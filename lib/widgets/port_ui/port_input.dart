part of 'port_ui.dart';

/// Input — input.tsx. Заливка secondary без обводки в покое (кастомная
/// демка на shadcn.com, не дефолтный input.tsx border/bg-transparent — см.
/// docs/shadcn/PLAN.md), обводка/ring только на фокусе.
class PortInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? placeholder;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  const PortInput({
    super.key,
    this.controller,
    this.initialValue,
    this.placeholder,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  State<PortInput> createState() => _PortInputState();
}

class _PortInputState extends State<PortInput> {
  final _focusNode = FocusNode();
  TextEditingController? _ownedController;
  bool _focused = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController(text: widget.initialValue));

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _kDuration,
      curve: _kEase,
      height: 36,
      decoration: BoxDecoration(
        color: PortColors.secondary,
        borderRadius: BorderRadius.circular(kRadius * 0.8),
        border: Border.all(color: _focused ? PortColors.ring : Colors.transparent),
        boxShadow: [
          if (_focused) BoxShadow(color: PortColors.ring.withValues(alpha: 0.5), spreadRadius: 3),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
      alignment: Alignment.centerLeft,
      child: Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          onSubmitted: widget.onSubmitted,
          style: const TextStyle(color: PortColors.foreground, fontSize: 14),
          cursorColor: PortColors.primary,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: widget.placeholder,
            hintStyle: const TextStyle(color: PortColors.mutedForeground, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
