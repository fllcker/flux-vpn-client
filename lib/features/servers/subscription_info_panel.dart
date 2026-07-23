import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core_abstraction/core_config_provider.dart';
import 'flatten_leaves.dart';
import 'right_panel_view.dart';

class SubscriptionInfoPanel extends ConsumerWidget {
  final String subscriptionId;
  const SubscriptionInfoPanel({super.key, required this.subscriptionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final subscriptions = ref.watch(coreConfigProvider).subscriptions;
    final subscription = subscriptions
        .where((s) => s.id == subscriptionId)
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
            Text(subscription.name, style: theme.textTheme.h4),
            const SizedBox(height: 4),
            Text(
              subscription.url,
              style: theme.textTheme.muted,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            _InfoRow(label: 'Серверов', value: '$serverCount'),
            if (subscription.lastRefreshedAt != null)
              _InfoRow(
                label: 'Обновлено',
                value: _formatDateTime(subscription.lastRefreshedAt!),
              ),
            if (subscription.expiresAt != null)
              _InfoRow(
                label: 'Истекает',
                value: _formatDateTime(subscription.expiresAt!),
              ),
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
            const SizedBox(height: 24),
            ShadButton.destructive(
              onPressed: () {
                ref
                    .read(coreConfigProvider.notifier)
                    .removeSubscription(subscriptionId);
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
