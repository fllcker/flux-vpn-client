import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/dialog_style.dart';
import '../../core_abstraction/app_settings_provider.dart';
import '../../core_abstraction/core_config_provider.dart';
import '../../widgets/port_ui/port_ui.dart';
import 'apply_mj_payload.dart';
import 'subscription_import.dart';

/// Небольшой диалог по центру окна для добавления `vless://` ссылки или
/// подписки — обычный `PortDialog`, а не полноразмерный Sheet: так привычнее
/// выглядит и не отвлекает на весь экран ради одного поля ввода.
///
/// [initialLink] позволяет предзаполнить поле — используется диплинком
/// `flux://add/...` и глобальной вставкой по Ctrl+V.
class ImportSubscriptionSheet extends ConsumerStatefulWidget {
  final String? initialLink;

  const ImportSubscriptionSheet({super.key, this.initialLink});

  @override
  ConsumerState<ImportSubscriptionSheet> createState() =>
      _ImportSubscriptionSheetState();
}

class _ImportSubscriptionSheetState
    extends ConsumerState<ImportSubscriptionSheet> {
  late final _linkController = TextEditingController(
    text: widget.initialLink ?? '',
  );
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final autoGroup = ref.read(appSettingsProvider).autoGroupSubscriptions;
    final result = await importLink(link, autoGroup: autoGroup);
    if (!mounted) return;

    switch (result) {
      case SingleServerImportResult(:final leaf):
        ref.read(coreConfigProvider.notifier).addServers([leaf]);
        Navigator.of(context).pop();
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
            ref.read(coreConfigProvider.notifier).updateSubscription(subscription);
          }
        } else {
          ref.read(coreConfigProvider.notifier).addSubscription(subscription);
        }
        Navigator.of(context).pop();
      case MjImportResultOk(:final payload):
        applyMjPayload(ref, payload);
        Navigator.of(context).pop();
      case LinkImportFailure(:final reason):
        setState(() {
          _loading = false;
          _error = reason;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortDialog(
      title: const Text('Добавить сервер'),
      description: const Text('Ссылка на подписку или vless:// ссылка'),
      actions: [
        PortButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Добавление...' : 'Добавить'),
        ),
      ],
      child: SizedBox(
        width: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PortInput(
              controller: _linkController,
              placeholder: 'https://... или vless://...',
              enabled: !_loading,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: PortText.muted.copyWith(
                  color: const Color(0xFFF87171),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Показывает диалог добавления сервера по центру окна.
Future<void> showAddServerDialog(
  BuildContext context, {
  String? initialLink,
}) {
  return showPortDialog(
    context: context,
    barrierColor: dialogBarrierColor,
    builder: (_) => ImportSubscriptionSheet(initialLink: initialLink),
  );
}
