import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/subscription.dart';
import 'flatten_leaves.dart';
import 'reset_subscription_order.dart';
import 'right_panel_view.dart';
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

  Future<void> _refresh(Subscription subscription) async {
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });

    final result = await refreshSubscription(subscription);
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
          _refreshError = 'Ссылка подписки больше не отдаёт подписку';
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
    final theme = ShadTheme.of(context);
    final subscriptions = ref.watch(coreConfigProvider).subscriptions;
    final subscription = subscriptions
        .where((s) => s.id == widget.subscriptionId)
        .firstOrNull;

    if (subscription == null) {
      return Center(
        child: Text('Подписка удалена', style: theme.textTheme.muted),
      );
    }

    final allLeaves = flattenLeaves([subscription.root]);
    final serverCount = allLeaves.length;
    final hiddenLeaves = allLeaves.where((l) => l.hidden).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(subscription.name, style: theme.textTheme.h4),
                ),
                ShadIconButton.ghost(
                  icon: Icon(
                    LucideIcons.refreshCw,
                    size: 16,
                    color: _refreshing
                        ? theme.colorScheme.mutedForeground
                        : null,
                  ),
                  onPressed: _refreshing ? null : () => _refresh(subscription),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_editingUrl)
              Row(
                children: [
                  Expanded(
                    child: ShadInput(
                      controller: _urlController,
                      onSubmitted: (_) => _saveUrl(subscription),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ShadIconButton.ghost(
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
                        style: theme.textTheme.muted,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      LucideIcons.pencil,
                      size: 12,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ],
                ),
              ),
            if (_refreshError != null) ...[
              const SizedBox(height: 6),
              Text(
                _refreshError!,
                style: theme.textTheme.muted.copyWith(
                  color: const Color(0xFFF87171),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _InfoRow(label: 'Серверов', value: '$serverCount'),
            if (subscription.lastRefreshedAt != null)
              _InfoRow(
                label: 'Обновлено',
                value: _formatDateTime(subscription.lastRefreshedAt!),
              ),
            if (subscription.expiresAt != null) ...[
              _InfoRow(
                label: 'Истекает',
                value: _formatDateTime(subscription.expiresAt!),
              ),
              _InfoRow(
                label: 'Осталось',
                value: _formatDaysLeft(subscription.expiresAt!),
              ),
            ],
            if (subscription.traffic case final traffic?)
              _InfoRow(
                label: 'Трафик',
                value:
                    '${_formatBytes(traffic.usedBytes)} / '
                    '${_formatBytes(traffic.totalBytes)}',
              ),
            if (subscription.annotation case final annotation?
                when annotation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(annotation, style: theme.textTheme.small),
            ],
            const SizedBox(height: 20),
            ShadSwitch(
              value: subscription.autoRefreshOnStartup,
              label: const Text('Обновлять при запуске приложения'),
              onChanged: (value) => ref
                  .read(coreConfigProvider.notifier)
                  .updateSubscription(
                    subscription.copyWith(autoRefreshOnStartup: value),
                  ),
            ),
            const SizedBox(height: 12),
            ShadButton.outline(
              onPressed: () {
                final root = subscription.root;
                if (root is! ServerGroup) return;
                ref
                    .read(coreConfigProvider.notifier)
                    .updateSubscription(
                      subscription.copyWith(root: rebuildDefaultOrder(root)),
                    );
              },
              leading: const Icon(LucideIcons.rotateCcw, size: 14),
              child: const Text('Сбросить сортировку'),
            ),
            if (hiddenLeaves.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Скрытые серверы',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.mutedForeground,
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
                          style: theme.textTheme.small,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ShadButton.ghost(
                        onPressed: () => ref
                            .read(coreConfigProvider.notifier)
                            .setHidden(leaf.id, false),
                        child: const Text('Вернуть'),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 20),
            _RoutingSection(subscription: subscription, allLeaves: allLeaves),
            const SizedBox(height: 24),
            ShadButton.destructive(
              onPressed: () {
                ref
                    .read(coreConfigProvider.notifier)
                    .removeSubscription(widget.subscriptionId);
                ref.read(rightPanelViewProvider.notifier).showConnect();
              },
              child: const Text('Удалить подписку'),
            ),
          ],
        ),
      ),
    );
  }
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
    final theme = ShadTheme.of(context);
    if (allLeaves.isEmpty) return const SizedBox.shrink();

    final first = allLeaves.first.routingRules;
    final identical = allLeaves.every(
      (l) => _rulesEqual(l.routingRules, first),
    );

    void editCommon() {
      showRoutingRulesDialog(
        context,
        title: 'Роутинг — ${subscription.name}',
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
                'Роутинг',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ),
            if (identical)
              ShadIconButton.ghost(
                icon: const Icon(LucideIcons.pencil, size: 14),
                onPressed: editCommon,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (identical)
          Text(
            first.isEmpty
                ? 'Правил нет — весь трафик через прокси'
                : '${first.length} ${_ruleWord(first.length)}',
            style: theme.textTheme.muted,
          )
        else ...[
          Text(
            'Правила различаются по серверам',
            style: theme.textTheme.muted,
          ),
          const SizedBox(height: 8),
          ShadButton.outline(
            onPressed: editCommon,
            child: const Text('Задать одинаковые правила для всех'),
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
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.muted),
          Text(value, style: theme.textTheme.small),
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
  if (days < 0) return 'истекла';
  if (days == 0) return 'меньше дня';
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
