import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core_abstraction/core_config_provider.dart';
import 'flatten_leaves.dart';
import 'import_subscription_sheet.dart';
import 'selected_server_provider.dart';
import 'server_row.dart';
import 'server_sections.dart';

class ServerListPanel extends ConsumerWidget {
  const ServerListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final config = ref.watch(coreConfigProvider);
    final sections = buildServerSections(config);
    final allLeaves = flattenAllLeaves(config);
    final selectedId =
        ref.watch(selectedServerIdProvider) ??
        (allLeaves.isNotEmpty ? allLeaves.first.id : null);

    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 10, 12),
            child: Row(
              children: [
                Expanded(child: Text('Серверы', style: theme.textTheme.h4)),
                ShadIconButton.ghost(
                  icon: const Icon(LucideIcons.plus, size: 18),
                  onPressed: () => showShadSheet(
                    context: context,
                    builder: (_) => const ImportSubscriptionSheet(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: allLeaves.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'Пока нет серверов — добавьте подписку или ссылку.',
                      style: theme.textTheme.muted,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final section in sections)
                        _ServerSectionView(
                          section: section,
                          selectedId: selectedId,
                          onSelect: (id) => ref
                              .read(selectedServerIdProvider.notifier)
                              .select(id),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServerSectionView extends StatelessWidget {
  final ServerSection section;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _ServerSectionView({
    required this.section,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (section.title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
            child: Text(
              section.title!.toUpperCase(),
              style: theme.textTheme.muted.copyWith(
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ),
        for (final leaf in section.leaves)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ServerRow(
              name: leaf.name,
              icon: leaf.icon,
              selected: leaf.id == selectedId,
              onTap: () => onSelect(leaf.id),
            ),
          ),
      ],
    );
  }
}
