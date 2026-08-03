import 'dart:async';

import 'package:flutter/material.dart' show Colors, Material;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/dialog_style.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../engines/geo_category_index.dart';
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
  final String initialDefaultOutboundTag;
  final void Function(
    String name,
    List<RoutingRule> rules,
    String defaultOutboundTag,
  ) onSave;

  const RoutingRulesDialog({
    super.key,
    required this.title,
    required this.initialName,
    required this.initialRules,
    required this.initialDefaultOutboundTag,
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
  late String _defaultOutboundTag;

  // Автокомплит geosite/geoip (см. `geo_category_index.dart`) — плавающий
  // попап под полем значения правила, по образцу shadcn Combobox: не
  // раскрывается на пустом поле (категорий в geosite/geoip слишком много),
  // только когда что-то введено и что-то нашлось, до 5 вариантов.
  final _valueFieldKey = GlobalKey();
  final _valueFieldLink = LayerLink();
  OverlayEntry? _suggestionsEntry;
  List<String> _suggestions = const [];
  double _suggestionsWidth = 0;
  List<String> _geositeCategories = const [];
  List<String> _geoipCategories = const [];

  @override
  void initState() {
    super.initState();
    _rules = List.of(widget.initialRules);
    _nameController = TextEditingController(text: widget.initialName);
    _defaultOutboundTag = widget.initialDefaultOutboundTag;
    _valueController.addListener(_updateSuggestions);
    unawaited(_loadCategories());
  }

  Future<void> _loadCategories() async {
    final geosite = await geositeCategoryNames();
    final geoip = await geoipCategoryNames();
    if (!mounted) return;
    _geositeCategories = geosite;
    _geoipCategories = geoip;
  }

  @override
  void dispose() {
    _valueController.removeListener(_updateSuggestions);
    _suggestionsEntry?.remove();
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _updateSuggestions() {
    final categories = switch (_kind) {
      _RuleKind.domain => _geositeCategories,
      _RuleKind.ip => _geoipCategories,
    };
    final prefix = _kind == _RuleKind.domain ? 'geosite:' : 'geoip:';
    var query = _valueController.text.trim().toLowerCase();
    if (query.startsWith(prefix)) query = query.substring(prefix.length);

    final matches = query.isEmpty
        ? const <String>[]
        : categories.where((c) => c.contains(query)).take(5).toList();

    if (matches.isEmpty) {
      _closeSuggestions();
      return;
    }
    _suggestions = matches;
    final box = _valueFieldKey.currentContext?.findRenderObject() as RenderBox?;
    _suggestionsWidth = box?.size.width ?? _suggestionsWidth;
    if (_suggestionsEntry == null) {
      _suggestionsEntry = OverlayEntry(builder: (_) => _buildSuggestionsPopover());
      Overlay.of(context).insert(_suggestionsEntry!);
    } else {
      _suggestionsEntry!.markNeedsBuild();
    }
  }

  void _closeSuggestions() {
    _suggestions = const [];
    _suggestionsEntry?.remove();
    _suggestionsEntry = null;
  }

  void _selectSuggestion(String name) {
    final prefix = _kind == _RuleKind.domain ? 'geosite:' : 'geoip:';
    _valueController.text = '$prefix$name';
    _valueController.selection = TextSelection.collapsed(
      offset: _valueController.text.length,
    );
    _closeSuggestions();
  }

  Widget _buildSuggestionsPopover() {
    // Overlay даёт корню entry тугие constraints во весь экран — без
    // Stack+Positioned.fill (тот же приём, что в `PortSelect._open`) их
    // некому ослабить для не-Positioned ребёнка, и Container ниже вместо
    // своей ширины/высоты растягивается на весь экран вправо и вниз.
    return Stack(
      children: [
        const Positioned.fill(child: SizedBox.shrink()),
        CompositedTransformFollower(
          link: _valueFieldLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: _suggestionsWidth > 0 ? _suggestionsWidth : null,
              decoration: BoxDecoration(
                color: PortColors.popover,
                borderRadius: BorderRadius.circular(kRadius * 0.8),
                border: Border.all(color: PortColors.border),
                boxShadow: const [
                  BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.25), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final name in _suggestions)
                    _SuggestionItem(text: name, onTap: () => _selectSuggestion(name)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
    widget.onSave(name, _rules, _defaultOutboundTag);
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
            Text(S.defaultOutboundLabel, style: PortText.small),
            const SizedBox(height: 6),
            PortSelect<String>(
              initialValue: _defaultOutboundTag,
              onChanged: (value) {
                if (value != null) setState(() => _defaultOutboundTag = value);
              },
              options: [
                PortSelectOption(value: 'proxy', child: Text(S.throughProxy)),
                PortSelectOption(value: 'direct', child: Text(S.direct)),
                PortSelectOption(value: 'block', child: Text(S.block)),
              ],
              selectedOptionBuilder: (context, value) => Text(_tagLabel(value)),
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
                      if (value != null) {
                        setState(() => _kind = value);
                        _closeSuggestions();
                      }
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
                  child: CompositedTransformTarget(
                    link: _valueFieldLink,
                    child: PortInput(
                      key: _valueFieldKey,
                      controller: _valueController,
                      placeholder: 'example.com / geosite:category-ads',
                      onSubmitted: (_) => _addRule(),
                    ),
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

/// Один пункт в попапе автокомплита geosite/geoip
/// (`_RoutingRulesDialogState._buildSuggestionsPopover`) — визуально тот же
/// hover-паттерн, что и у `_SelectItem` из `port_select.dart`.
class _SuggestionItem extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionItem({required this.text, required this.onTap});

  @override
  State<_SuggestionItem> createState() => _SuggestionItemState();
}

class _SuggestionItemState extends State<_SuggestionItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? PortColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadius * 0.6),
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: 14,
              color: _hovered ? PortColors.accentForeground : PortColors.foreground,
            ),
          ),
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
  required String initialDefaultOutboundTag,
  required void Function(
    String name,
    List<RoutingRule> rules,
    String defaultOutboundTag,
  ) onSave,
}) {
  return showPortDialog(
    context: context,
    barrierColor: dialogBarrierColor,
    builder: (_) => RoutingRulesDialog(
      title: title,
      initialName: initialName,
      initialRules: initialRules,
      initialDefaultOutboundTag: initialDefaultOutboundTag,
      onSave: onSave,
    ),
  );
}
