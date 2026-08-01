import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/dialog_style.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../l10n/strings.dart';
import '../../widgets/port_ui/port_ui.dart';

/// Одно редактируемое правило в UI — каждое поле формы создаёт свой
/// [RoutingRule] с одним значением (без группировки нескольких значений под
/// один outboundTag) — проще в реализации и редактировании, xray одинаково
/// понимает как один rule-объект с массивом значений, так и несколько
/// объектов с одним значением каждый.
enum _RuleKind { domain, ip }

/// Диалог создания/редактирования именованного пресета роутинга
/// (`routing_preset.dart`) — вызывается из настроек (`settings_page.dart`),
/// см. ROADMAP.md, трек 3.
class RoutingRulesDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final List<RoutingRule> initialRules;
  final void Function(String name, List<RoutingRule> rules) onSave;

  const RoutingRulesDialog({
    super.key,
    required this.title,
    required this.initialName,
    required this.initialRules,
    required this.onSave,
  });

  @override
  State<RoutingRulesDialog> createState() => _RoutingRulesDialogState();
}

class _RoutingRulesDialogState extends State<RoutingRulesDialog> {
  late List<RoutingRule> _rules;
  late final TextEditingController _nameController;
  final _valueController = TextEditingController();
  _RuleKind _kind = _RuleKind.domain;
  String _outboundTag = 'proxy';

  @override
  void initState() {
    super.initState();
    _rules = List.of(widget.initialRules);
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _addRule() {
    final value = _valueController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _rules = [
        ..._rules,
        switch (_kind) {
          _RuleKind.domain => DomainRule(
            values: [value],
            outboundTag: _outboundTag,
          ),
          _RuleKind.ip => IpRule(values: [value], outboundTag: _outboundTag),
        },
      ];
      _valueController.clear();
    });
  }

  void _removeAt(int index) {
    setState(() => _rules = [..._rules]..removeAt(index));
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.onSave(name, _rules);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PortDialog(
      title: Text(widget.title),
      child: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.presetNameLabel, style: PortText.small),
            const SizedBox(height: 6),
            PortInput(
              controller: _nameController,
              placeholder: S.presetNamePlaceholder,
            ),
            const SizedBox(height: 16),
            if (_rules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(S.noRulesYet, style: PortText.muted),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _rules.length,
                  itemBuilder: (context, index) =>
                      _RuleTile(rule: _rules[index], onRemove: () => _removeAt(index)),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: PortSelect<_RuleKind>(
                    initialValue: _kind,
                    onChanged: (value) {
                      if (value != null) setState(() => _kind = value);
                    },
                    options: [
                      PortSelectOption(value: _RuleKind.domain, child: Text(S.domain)),
                      const PortSelectOption(value: _RuleKind.ip, child: Text('IP')),
                    ],
                    selectedOptionBuilder: (context, value) => Text(
                      switch (value) {
                        _RuleKind.domain => S.domain,
                        _RuleKind.ip => 'IP',
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PortInput(
                    controller: _valueController,
                    placeholder: 'example.com / geosite:category-ads',
                    onSubmitted: (_) => _addRule(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PortSelect<String>(
                    initialValue: _outboundTag,
                    onChanged: (value) {
                      if (value != null) setState(() => _outboundTag = value);
                    },
                    options: [
                      PortSelectOption(value: 'proxy', child: Text(S.throughProxy)),
                      PortSelectOption(value: 'direct', child: Text(S.direct)),
                      PortSelectOption(value: 'block', child: Text(S.block)),
                    ],
                    selectedOptionBuilder: (context, value) => Text(_tagLabel(value)),
                  ),
                ),
                const SizedBox(width: 8),
                PortButton(onPressed: _addRule, child: Text(S.add)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PortButton.outline(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.cancel),
                ),
                const SizedBox(width: 8),
                PortButton(onPressed: _save, child: Text(S.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final RoutingRule rule;
  final VoidCallback onRemove;
  const _RuleTile({required this.rule, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final (kindLabel, values, outboundTag) = switch (rule) {
      DomainRule(:final values, :final outboundTag) => (S.domain, values, outboundTag),
      IpRule(:final values, :final outboundTag) => ('IP', values, outboundTag),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: PortText.small,
                children: [
                  TextSpan(
                    text: '$kindLabel  ',
                    style: TextStyle(color: PortColors.mutedForeground),
                  ),
                  TextSpan(text: values.join(', ')),
                  TextSpan(
                    text: '  → ${_tagLabel(outboundTag)}',
                    style: TextStyle(color: PortColors.mutedForeground),
                  ),
                ],
              ),
            ),
          ),
          PortIconButton.ghost(
            icon: const Icon(LucideIcons.trash2, size: 14),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

String _tagLabel(String outboundTag) => switch (outboundTag) {
  'direct' => S.direct,
  'block' => S.block,
  _ => S.throughProxy,
};

/// Показывает диалог создания/редактирования пресета роутинга по центру
/// окна — тот же стиль, что и остальные диалоги приложения (см.
/// `showSettingsDialog`, `showAddServerDialog`).
Future<void> showRoutingRulesDialog(
  BuildContext context, {
  required String title,
  required String initialName,
  required List<RoutingRule> initialRules,
  required void Function(String name, List<RoutingRule> rules) onSave,
}) {
  return showPortDialog(
    context: context,
    barrierColor: dialogBarrierColor,
    builder: (_) => RoutingRulesDialog(
      title: title,
      initialName: initialName,
      initialRules: initialRules,
      onSave: onSave,
    ),
  );
}
