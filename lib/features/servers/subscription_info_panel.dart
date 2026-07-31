import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/subscription.dart';
import '../../l10n/app_locale.dart';
import '../../l10n/strings.dart';
import '../../widgets/port_ui/port_ui.dart';
import 'flatten_leaves.dart';
import 'routing_rules_dialog.dart';
import 'server_icon.dart';
import 'subscription_import.dart';

class SubscriptionInfoPanel extends ConsumerStatefulWidget {
  final String subscriptionId;
  const SubscriptionInfoPanel({super.key, required this.subscriptionId});

  @override
  ConsumerState<SubscriptionInfoPanel> createState() =>
      _SubscriptionInfoPanelState();
}

class _SubscriptionInfoPanelState extends ConsumerState<SubscriptionInfoPanel> {
  bool _refreshing = false;
  String? _refreshError;
  bool _editingUrl = false;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _refresh(
    Subscription subscription, {
    bool resetOrder = false,
  }) async {
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });

    final result = await refreshSubscription(
      subscription,
      resetOrder: resetOrder,
    );
    if (!mounted) return;

    switch (result) {
      case SubscriptionImportResultOk(:final subscription):
        ref.read(coreConfigProvider.notifier).updateSubscription(subscription);
        setState(() => _refreshing = false);
      case LinkImportFailure(:final reason):
        setState(() {
          _refreshing = false;
          _refreshError = reason;
        });
      case SingleServerImportResult():
        setState(() {
          _refreshing = false;
          _refreshError = S.subscriptionNoLongerServing;
        });
      case MjImportResultOk():
        // refreshSubscription() сам разворачивает MjSubscriptionsPayload в
        // SubscriptionImportResultOk (см. subscription_import.dart) — сюда
        // долетает только если сервис вдруг прислал 'nodes' вместо
        // 'subscriptions' на URL этой подписки, тогда refreshSubscription
        // уже вернул LinkImportFailure, а не это. Ветка нужна только чтобы
        // switch был исчерпывающим по типу.
        setState(() {
          _refreshing = false;
          _refreshError = S.unexpectedMagicJsonResponse;
        });
    }
  }

  void _startEditingUrl(Subscription subscription) {
    _urlController.text = subscription.url;
    setState(() => _editingUrl = true);
  }

  void _saveUrl(Subscription subscription) {
    final url = _urlController.text.trim();
    setState(() => _editingUrl = false);
    if (url.isEmpty || url == subscription.url) return;
    ref
        .read(coreConfigProvider.notifier)
        .updateSubscription(subscription.copyWith(url: url));
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions = ref.watch(coreConfigProvider).subscriptions;
    final subscription = subscriptions
        .where((s) => s.id == widget.subscriptionId)
        .firstOrNull;

    if (subscription == null) {
      return Center(child: Text(S.subscriptionDeleted, style: PortText.muted));
    }

    final allLeaves = flattenLeaves([subscription.root]);
    final serverCount = allLeaves.length;
    final hiddenLeaves = allLeaves.where((l) => l.hidden).toList();

    // SingleChildScrollView — без него на узких/невысоких окнах (мобильная
    // раскладка, см. ROADMAP.md, трек 16) содержимое (заголовок, инфо-строки,
    // список скрытых серверов, роутинг) легко превышает высоту экрана и
    // переполняется вертикально; Center внутри скролла по-прежнему
    // центрирует по горизонтали (высота вдоль оси скролла не ограничена,
    // Center просто сжимается по контенту).
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(subscription.name, style: PortText.h4)),
                  PortIconButton.ghost(
                    icon: Icon(
                      LucideIcons.refreshCw,
                      size: 16,
                      color: _refreshing ? PortColors.mutedForeground : null,
                    ),
                    onPressed: _refreshing
                        ? null
                        : () => _refresh(subscription),
                  ),
                  // Панель теперь всегда открывается поверх главного экрана
                  // (диалог на десктопе — showSubscriptionInfoDialog ниже,
                  // bottom sheet на мобилке — см. server_list_panel.dart), а
                  // не встраивается в постоянную колонку, как раньше — явная
                  // кнопка закрытия нужна, кликом вне/свайпом одно не всегда
                  // очевидно.
                  const SizedBox(width: 4),
                  PortIconButton.ghost(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_editingUrl)
                Row(
                  children: [
                    Expanded(
                      child: PortInput(
                        controller: _urlController,
                        onSubmitted: (_) => _saveUrl(subscription),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PortIconButton.ghost(
                      icon: const Icon(LucideIcons.check, size: 16),
                      onPressed: () => _saveUrl(subscription),
                    ),
                  ],
                )
              else
                GestureDetector(
                  onTap: () => _startEditingUrl(subscription),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subscription.url,
                          style: PortText.muted,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        LucideIcons.pencil,
                        size: 12,
                        color: PortColors.mutedForeground,
                      ),
                    ],
                  ),
                ),
              if (_refreshError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _refreshError!,
                  style: PortText.muted.copyWith(
                    color: const Color(0xFFF87171),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _InfoRow(label: S.servers, value: '$serverCount'),
              if (subscription.lastRefreshedAt != null)
                _InfoRow(
                  label: S.updated,
                  value: _formatDateTime(subscription.lastRefreshedAt!),
                ),
              if (subscription.expiresAt != null) ...[
                _InfoRow(
                  label: S.expiresLabel,
                  value: _formatDateTime(subscription.expiresAt!),
                ),
                _InfoRow(
                  label: S.remaining,
                  value: _formatDaysLeft(subscription.expiresAt!),
                ),
              ],
              if (subscription.traffic case final traffic?)
                _InfoRow(
                  label: S.traffic,
                  value:
                      '${_formatBytes(traffic.usedBytes)} / '
                      '${_formatBytes(traffic.totalBytes)}',
                ),
              for (final entry in subscription.customFields.entries)
                _InfoRow(label: entry.key, value: entry.value),
              if (subscription.annotation case final annotation?
                  when annotation.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(annotation, style: PortText.small),
              ],
              const SizedBox(height: 20),
              PortSwitch(
                value: subscription.autoRefreshOnStartup,
                label: Text(S.refreshOnStartup),
                onChanged: (value) => ref
                    .read(coreConfigProvider.notifier)
                    .updateSubscription(
                      subscription.copyWith(autoRefreshOnStartup: value),
                    ),
              ),
              const SizedBox(height: 12),
              PortButton.outline(
                onPressed: _refreshing
                    ? null
                    : () => _refresh(subscription, resetOrder: true),
                leading: const Icon(LucideIcons.rotateCcw, size: 14),
                child: Text(S.resetSorting),
              ),
              if (hiddenLeaves.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  S.hiddenServers,
                  style: PortText.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PortColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                for (final leaf in hiddenLeaves)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        ServerIcon(icon: leaf.icon, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            leaf.name,
                            style: PortText.small,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PortButton.ghost(
                          onPressed: () => ref
                              .read(coreConfigProvider.notifier)
                              .setHidden(leaf.id, false),
                          child: Text(S.restore),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              _RoutingSection(subscription: subscription, allLeaves: allLeaves),
              const SizedBox(height: 24),
              PortButton.destructive(
                onPressed: () {
                  ref
                      .read(coreConfigProvider.notifier)
                      .removeSubscription(widget.subscriptionId);
                  Navigator.of(context).pop();
                },
                child: Text(S.deleteSubscription),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Десктопная обёртка — модалка вместо постоянной правой колонки (см.
/// ROADMAP.md/чат: раньше подписка заменяла ConnectPanel в rightPanelView,
/// что и на десктопе было неудобно — не было явного "назад", только клик по
/// серверу). Не переиспользует `PortDialog` целиком — тот сам оборачивает
/// контент в свой `SingleChildScrollView`/`Column` с заголовком, а
/// [SubscriptionInfoPanel] уже полностью самодостаточен (свой скролл,
/// паддинг, maxWidth, теперь и своя кнопка закрытия) — вложение дало бы
/// двойной скролл и задвоенный паддинг. Берём только карточную "оболочку"
/// (фон/бордер/тень/скругление) из PortDialog.
Future<void> showSubscriptionInfoDialog(
  BuildContext context, {
  required String subscriptionId,
}) {
  return showPortDialog<void>(
    context: context,
    builder: (context) => Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height - 64,
        ),
        decoration: BoxDecoration(
          color: PortColors.background,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: PortColors.border),
          boxShadow: const [
            BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 24, offset: Offset(0, 12)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SubscriptionInfoPanel(subscriptionId: subscriptionId),
      ),
    ),
  );
}

/// Секция "Роутинг" — правила живут на каждом [ServerLeaf] отдельно (см.
/// ROADMAP.md, трек 3), поэтому у подписки нет одного "истинного" набора
/// правил. Показываем общий набор, если он одинаков у всех серверов
/// подписки, иначе — предупреждение с кнопкой bulk-применения.
class _RoutingSection extends ConsumerWidget {
  final Subscription subscription;
  final List<ServerLeaf> allLeaves;

  const _RoutingSection({required this.subscription, required this.allLeaves});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (allLeaves.isEmpty) return const SizedBox.shrink();

    final first = allLeaves.first.routingRules;
    final identical = allLeaves.every(
      (l) => _rulesEqual(l.routingRules, first),
    );

    void editCommon() {
      showRoutingRulesDialog(
        context,
        title: S.routingTitleFor(subscription.name),
        initialRules: identical ? first : const [],
        onSave: (rules) => ref
            .read(coreConfigProvider.notifier)
            .setRoutingRulesForSubscription(subscription.id, rules),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.routing,
                style: PortText.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: PortColors.mutedForeground,
                ),
              ),
            ),
            if (identical)
              PortIconButton.ghost(
                icon: const Icon(LucideIcons.pencil, size: 14),
                onPressed: editCommon,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (identical)
          Text(
            first.isEmpty
                ? S.noRulesAllViaProxy
                : '${first.length} ${_ruleWord(first.length)}',
            style: PortText.muted,
          )
        else ...[
          Text(S.rulesDifferBetweenServers, style: PortText.muted),
          const SizedBox(height: 8),
          PortButton.outline(
            onPressed: editCommon,
            child: Text(S.setSameRulesForAll),
          ),
        ],
      ],
    );
  }
}

bool _rulesEqual(List<RoutingRule> a, List<RoutingRule> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (jsonEncode(a[i].toJson()) != jsonEncode(b[i].toJson())) return false;
  }
  return true;
}

String _ruleWord(int count) {
  if (AppLocale.effective == AppLanguage.en) return count == 1 ? 'rule' : 'rules';
  final lastDigit = count % 10;
  final lastTwoDigits = count % 100;
  if (lastTwoDigits >= 11 && lastTwoDigits <= 14) return 'правил';
  return switch (lastDigit) {
    1 => 'правило',
    2 || 3 || 4 => 'правила',
    _ => 'правил',
  };
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    // Обычно value — короткая строка (число, дата), и spaceBetween без
    // Expanded давал тот же результат нагляднее. Но customFields (см. цикл
    // в build() выше) может прилететь с сервера сырой длинной строкой —
    // без Expanded она просто переполняла Row и переносилась с выравниванием
    // по левому краю, ломая колонку "ярлык / значение". Expanded + end
    // сохраняет прежний вид для коротких значений и переносит длинные
    // вправо-выровненным блоком вместо переполнения.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        // baseline, не start — label (PortText.muted, дефолтный line-height
        // шрифта) и value (PortText.small, height: 1) имеют разную высоту
        // строки, из-за чего start выравнивал верх текстовых боксов, а не
        // видимые глифы: value visually сидел выше label. Baseline
        // выравнивает по фактической базовой линии символов независимо от
        // разницы в line-height.
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label, style: PortText.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: PortText.small, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

String _formatDaysLeft(DateTime expiresAt) {
  final days = expiresAt.difference(DateTime.now()).inDays;
  if (days < 0) return S.expired;
  if (days == 0) return S.lessThanADay;
  if (AppLocale.effective == AppLanguage.en) {
    return '$days ${days == 1 ? 'day' : 'days'}';
  }
  final lastDigit = days % 10;
  final lastTwoDigits = days % 100;
  final word = (lastTwoDigits >= 11 && lastTwoDigits <= 14)
      ? 'дней'
      : switch (lastDigit) {
          1 => 'день',
          2 || 3 || 4 => 'дня',
          _ => 'дней',
        };
  return '$days $word';
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unitIndex]}';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
