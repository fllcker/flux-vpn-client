import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core_abstraction/core_config_provider.dart';
import 'subscription_import.dart';

class ImportSubscriptionSheet extends ConsumerStatefulWidget {
  const ImportSubscriptionSheet({super.key});

  @override
  ConsumerState<ImportSubscriptionSheet> createState() =>
      _ImportSubscriptionSheetState();
}

class _ImportSubscriptionSheetState
    extends ConsumerState<ImportSubscriptionSheet> {
  final _linkController = TextEditingController();
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

    final result = await importLink(link);
    if (!mounted) return;

    switch (result) {
      case SingleServerImportResult(:final leaf):
        ref.read(coreConfigProvider.notifier).addServers([leaf]);
        Navigator.of(context).pop();
      case SubscriptionImportResultOk(:final subscription):
        ref.read(coreConfigProvider.notifier).addSubscription(subscription);
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
    final theme = ShadTheme.of(context);

    return ShadSheet(
      title: const Text('Добавить сервер'),
      description: const Text('Ссылка на подписку или vless:// ссылка'),
      actions: [
        ShadButton(
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
            ShadInput(
              controller: _linkController,
              placeholder: const Text('https://... или vless://...'),
              enabled: !_loading,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.muted.copyWith(
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
