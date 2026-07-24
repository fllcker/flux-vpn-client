import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/subscription.dart';
import 'flatten_leaves.dart';
import 'right_panel_view.dart';
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

    final serverCount = flattenLeaves([subscription.root]).length;

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
