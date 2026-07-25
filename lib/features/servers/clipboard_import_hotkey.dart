import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core_abstraction/app_settings_provider.dart';
import '../../core_abstraction/core_config_provider.dart';
import '../../l10n/strings.dart';
import '../../widgets/port_ui/port_ui.dart';
import 'apply_mj_payload.dart';
import 'subscription_import.dart';

/// Глобальная вставка по Ctrl+V (Cmd+V на macOS): если в буфере обмена
/// лежит что-то похожее на `vless://` или `http(s)://` ссылку и фокус сейчас
/// не в текстовом поле (иначе это была бы обычная вставка текста),
/// пытаемся распознать это как сервер/подписку и добавить без открытия
/// диалога — как в других клиентах. Результат — короткий тост snackbar-
/// стиля снизу справа, который сам скрывается.
class ClipboardImportHotkey extends ConsumerStatefulWidget {
  final Widget child;

  const ClipboardImportHotkey({super.key, required this.child});

  @override
  ConsumerState<ClipboardImportHotkey> createState() =>
      _ClipboardImportHotkeyState();
}

class _ClipboardImportHotkeyState
    extends ConsumerState<ClipboardImportHotkey> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyV) return false;
    final hasModifier =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!hasModifier) return false;

    // Фокус в текстовом поле (например, в этом же диалоге добавления
    // сервера) — пусть отработает обычная вставка текста, не перехватываем.
    if (_focusIsEditable()) return false;

    unawaited(_tryImportFromClipboard());
    return false;
  }

  bool _focusIsEditable() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<void> _tryImportFromClipboard() async {
    if (_busy) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null) return;

    final looksLikeLink =
        text.startsWith('vless://') ||
        text.startsWith('hysteria2://') ||
        text.startsWith('hy2://') ||
        text.startsWith('http://') ||
        text.startsWith('https://');
    if (!looksLikeLink) return;

    _busy = true;
    try {
      final autoGroup = ref.read(appSettingsProvider).autoGroupSubscriptions;
      final result = await importLink(text, autoGroup: autoGroup);
      if (!mounted) return;

      switch (result) {
        case SingleServerImportResult(:final leaf):
          ref.read(coreConfigProvider.notifier).addServers([leaf]);
          _showToast(S.serverAddedFromClipboard, leaf.name);
        case SubscriptionImportResultOk(:final subscription):
          final existing = findSubscriptionByUrl(
            ref.read(coreConfigProvider).subscriptions,
            subscription.url,
          );
          if (existing != null) {
            final refreshed = await refreshSubscription(
              existing,
              autoGroup: autoGroup,
            );
            if (!mounted) return;
            if (refreshed case SubscriptionImportResultOk(:final subscription)) {
              ref
                  .read(coreConfigProvider.notifier)
                  .updateSubscription(subscription);
              _showToast(S.subscriptionUpdated, subscription.name);
            }
          } else {
            ref.read(coreConfigProvider.notifier).addSubscription(subscription);
            _showToast(S.subscriptionAddedFromClipboard, subscription.name);
          }
        case MjImportResultOk(:final payload):
          final summary = applyMjPayload(ref, payload);
          _showToast(S.magicJsonFromClipboard, summary);
        case LinkImportFailure(:final reason):
          _showErrorToast(reason);
      }
    } finally {
      _busy = false;
    }
  }

  void _showToast(String title, String description) {
    if (!mounted) return;
    PortToaster.of(context).show(
      PortToast(title: Text(title), description: Text(description)),
    );
  }

  void _showErrorToast(String reason) {
    if (!mounted) return;
    PortToaster.of(context).show(
      PortToast.destructive(
        title: Text(S.clipboardImportFailedTitle),
        description: Text(reason),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
