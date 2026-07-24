import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/app_settings_provider.dart';
import '../../core_abstraction/core_config_provider.dart';
import '../../widgets/globe/country_centroids.dart';
import '../../widgets/globe/shader_background.dart';
import '../../widgets/globe/sphere_globe.dart';
import '../../widgets/globe/starfield.dart';
import '../ping/ping_all.dart';
import '../servers/flag_emoji.dart';
import '../servers/flatten_leaves.dart';
import '../servers/right_panel_view.dart';
import '../servers/selected_server_provider.dart';
import '../servers/server_icon.dart';
import '../servers/server_list_panel.dart';
import '../servers/subscription_import.dart';
import '../servers/subscription_info_panel.dart';
import 'connect_panel.dart';

/// Главный экран: список серверов слева, справа — карточка подключения
/// либо (если выбрана подписка в списке) информация о ней.
class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  // Живёт вместе с экраном (не пересоздаётся на каждый build от Riverpod),
  // чтобы звёздное поле и глобус двигались синхронно по одному и тому же
  // углу поворота — см. sphere_globe.dart, GlobeRotationController.
  final _rotation = GlobeRotationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoRefreshSubscriptions();
      _pingAllOnStartup();
    });
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  Future<void> _autoRefreshSubscriptions() async {
    final subscriptions = ref
        .read(coreConfigProvider)
        .subscriptions
        .where((s) => s.autoRefreshOnStartup);
    final autoGroup = ref.read(appSettingsProvider).autoGroupSubscriptions;
    for (final subscription in subscriptions) {
      final result = await refreshSubscription(subscription, autoGroup: autoGroup);
      if (!mounted) return;
      if (result case SubscriptionImportResultOk(:final subscription)) {
        ref.read(coreConfigProvider.notifier).updateSubscription(subscription);
      }
    }
  }

  void _pingAllOnStartup() {
    if (!ref.read(appSettingsProvider).pingAllOnStartup) return;
    pingAllLeaves(ref, flattenAllLeaves(ref.read(coreConfigProvider)));
  }

  @override
  Widget build(BuildContext context) {
    final rightPanelView = ref.watch(rightPanelViewProvider);
    final theme = ShadTheme.of(context);
    final homeBackground = ref.watch(appSettingsProvider).homeBackground;
    final showBackground =
        rightPanelView is ConnectView && homeBackground != HomeBackground.none;

    return ColoredBox(
      color: theme.colorScheme.background,
      child: Row(
        children: [
          const ServerListPanel(),
          Expanded(
            child: Stack(
              children: [
                if (showBackground)
                  switch (homeBackground) {
                    HomeBackground.none => const SizedBox.shrink(),
                    HomeBackground.globe => Stack(
                      children: [
                        Positioned.fill(
                          child: Starfield(
                            color: theme.colorScheme.foreground,
                            rotation: _rotation,
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: SizedBox(
                              width: 620,
                              height: 620,
                              child: SphereGlobe(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.45,
                                ),
                                markers: _selectedServerMarker(context, ref),
                                rotationController: _rotation,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    HomeBackground.simpleGradient => const Positioned.fill(
                      child: ShaderBackground(
                        assetPath: 'shaders/simple_gradient.frag',
                      ),
                    ),
                    HomeBackground.colorBends => const Positioned.fill(
                      child: ShaderBackground(
                        assetPath: 'shaders/color_bends.frag',
                      ),
                    ),
                    HomeBackground.galaxy => const Positioned.fill(
                      child: ShaderBackground(assetPath: 'shaders/galaxy.frag'),
                    ),
                  },
                switch (rightPanelView) {
                  ConnectView() => const ConnectPanel(),
                  SubscriptionInfoView(:final subscriptionId) =>
                    SubscriptionInfoPanel(subscriptionId: subscriptionId),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<GlobeMarker> _selectedServerMarker(BuildContext context, WidgetRef ref) {
    final leaves = flattenAllLeaves(ref.watch(coreConfigProvider));
    final selectedId =
        ref.watch(selectedServerIdProvider) ??
        (leaves.isNotEmpty ? leaves.first.id : null);
    if (selectedId == null) return const [];

    final leaf = leaves.where((l) => l.id == selectedId).firstOrNull;
    if (leaf == null) return const [];

    final isoCode = isoCodeFromFlagEmoji(leaf.icon);
    final centroid = isoCode == null ? null : countryCentroids[isoCode];
    if (centroid == null) return const [];

    final theme = ShadTheme.of(context);
    return [
      GlobeMarker(
        lat: centroid.$1,
        lon: centroid.$2,
        label: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.popover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.border),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ServerIcon(icon: leaf.icon, size: 16),
                const SizedBox(width: 6),
                Text(leaf.name, style: theme.textTheme.small),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
