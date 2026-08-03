import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/dialog_style.dart';
import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/routing_preset.dart';
import '../../l10n/strings.dart';
import '../../widgets/port_ui/port_ui.dart';
import 'routing_preset_exchange.dart';

const _uuid = Uuid();

/// Диалог разового импорта пресета(ов) роутинга по прямой ссылке (например,
/// raw GitHub JSON) — тот же стиль запроса ссылки, что и
/// `ImportSubscriptionSheet` для серверов, но без создания живой подписки:
/// каждый распарсенный пресет один раз добавляется в профиль как обычный
/// пресет с `source: importedUrl` (см. `routing_preset_exchange.dart`).
class ImportRoutingPresetDialog extends ConsumerStatefulWidget {
  const ImportRoutingPresetDialog({super.key});

  @override
  ConsumerState<ImportRoutingPresetDialog> createState() =>
      _ImportRoutingPresetDialogState();
}

class _ImportRoutingPresetDialogState
    extends ConsumerState<ImportRoutingPresetDialog> {
  final _linkController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _linkController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final blueprints = await fetchRoutingPresetBlueprints(url);
      if (!mounted) return;
      final notifier = ref.read(coreConfigProvider.notifier);
      for (final blueprint in blueprints) {
        notifier.addRoutingPreset(
          RoutingPreset(
            id: _uuid.v4(),
            name: blueprint.name,
            rules: blueprint.rules,
            defaultOutboundTag: blueprint.defaultOutboundTag,
            source: RoutingPresetSource.importedUrl,
            sourceUrl: url,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${S.importPresetFailed} $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortDialog(
      title: Text(S.importPresetLabel),
      actions: [
        PortButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? S.adding : S.add),
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
              placeholder: S.presetLinkPlaceholder,
              enabled: !_loading,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: PortText.muted.copyWith(color: const Color(0xFFF87171)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Показывает диалог импорта пресета роутинга по центру окна.
Future<void> showImportRoutingPresetDialog(BuildContext context) {
  return showPortDialog(
    context: context,
    barrierColor: dialogBarrierColor,
    builder: (_) => const ImportRoutingPresetDialog(),
  );
}
