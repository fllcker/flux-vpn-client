import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/strings.dart';
import '../../widgets/port_ui/port_ui.dart';

class AssistantPanel extends StatefulWidget {
  final VoidCallback onClose;
  final List<String> Function()? serverNames;

  const AssistantPanel({super.key, required this.onClose, this.serverNames});

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _random = Random();
  final _messages = <({bool user, String text})>[];
  Timer? _reply;
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _messages.add((user: false, text: S.assistantGreeting));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(String text, {List<String>? answers}) {
    final message = text.trim();
    if (message.isEmpty || _typing) return;
    final answer = answers == null
        ? S.assistantFallback
        : answers[_random.nextInt(answers.length)];
    setState(() {
      _messages.add((user: true, text: message));
      _typing = true;
    });
    _input.clear();
    _scrollToBottom();
    _reply = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() {
        _messages.add((user: false, text: answer));
        _typing = false;
      });
      _scrollToBottom();
    });
  }

  void _recommendServer() {
    if (_typing) return;
    final servers = widget.serverNames?.call() ?? const <String>[];
    _send(
      S.assistantPickServer,
      answers: [
        if (servers.isEmpty)
          S.assistantNoServers
        else
          S.assistantServerRecommendation(
            servers[_random.nextInt(servers.length)],
          ),
      ],
    );
  }

  @override
  void dispose() {
    _reply?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prompts = S.assistantPrompts;
    return Container(
      decoration: BoxDecoration(
        color: PortColors.background,
        border: Border(left: BorderSide(color: PortColors.border)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(-8, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.sparkles,
                      size: 20,
                      color: PortColors.foreground,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(S.assistantTitle, style: PortText.large),
                    ),
                    Semantics(
                      label: S.assistantClose,
                      button: true,
                      child: PortIconButton.ghost(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: widget.onClose,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: _messages.length + (_typing ? 1 : 0),
                  itemBuilder: (context, index) {
                    final message = index < _messages.length
                        ? _messages[index]
                        : (user: false, text: S.assistantTyping);
                    return Align(
                      alignment: message.user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        margin: EdgeInsets.only(
                          bottom: 12,
                          left: message.user ? 24 : 0,
                          right: message.user ? 0 : 24,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: message.user
                              ? PortColors.primary
                              : PortColors.secondary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          message.text,
                          style: PortText.muted.copyWith(
                            color: message.user
                                ? PortColors.primaryForeground
                                : PortColors.foreground,
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: PortColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: PortInput(
                            controller: _input,
                            enabled: !_typing,
                            placeholder: S.assistantPlaceholder,
                            onSubmitted: _send,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          label: S.assistantSend,
                          button: true,
                          child: PortIconButton(
                            icon: const Icon(LucideIcons.arrowUp, size: 18),
                            onPressed: _typing
                                ? null
                                : () => _send(_input.text),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        PortButton.outline(
                          onPressed: _typing ? null : _recommendServer,
                          child: Text(
                            S.assistantPickServer,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        for (final prompt in prompts)
                          PortButton.outline(
                            onPressed: _typing
                                ? null
                                : () => _send(
                                    prompt.question,
                                    answers: prompt.answers,
                                  ),
                            child: Text(
                              prompt.question,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
