import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/layout_breakpoints.dart';
import '../../app/notifications.dart';
import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/app_settings_provider.dart';
import '../../core_abstraction/connection_session.dart';
import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../engines/geo_assets.dart';
import '../../engines/singbox/geo_ruleset_cache.dart';
import '../../engines/xray/windows_elevation.dart';
import '../../l10n/strings.dart';
import '../../widgets/globe/country_centroids.dart';
import '../../widgets/globe/shader_background.dart';
import '../../widgets/globe/sphere_globe.dart';
import '../../widgets/globe/starfield.dart';
import '../../widgets/globe/video_background.dart';
import '../../widgets/port_ui/port_ui.dart';
import '../ping/ping_all.dart';
import '../servers/flag_emoji.dart';
import '../servers/flatten_leaves.dart';
import '../servers/selected_server_provider.dart';
import '../servers/server_icon.dart';
import '../servers/server_list_panel.dart';
import '../servers/subscription_import.dart';
import 'connect_panel.dart';
import 'connection_controller.dart';

/// Главный экран: список серверов слева, справа — карточка подключения
/// либо (если выбрана подписка в списке) информация о ней.
class ConnectionScreen extends ConsumerStatefulWidget {
  /// Плавающая кнопка настроек в мобильной раскладке (см. `build`) — на
  /// Android нет `AppTitleBar` (десктопный тайтлбар, см. `main.dart`), это
  /// единственный путь туда. `null` на десктопе, там открывает `AppTitleBar`.
  final VoidCallback? onOpenSettings;

  const ConnectionScreen({super.key, this.onOpenSettings});

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupSequence());
  }

  /// Автоподключение (см. `_autoConnectOnStartup`) должно строго идти
  /// последним — раньше эти вызовы не дожидались друг друга, что для
  /// автоподключения небезопасно: пока `_autoRefreshSubscriptions()` ещё
  /// пересобирает дерево, `lastSelectedServerId` может как раз исчезнуть/
  /// замениться (см. трек 9), и автоконнект либо промахнётся мимо сервера,
  /// либо подключится к тому, что через мгновение пропадёт. Прогрев
  /// geoip/geosite (включая rule-set'ы, трек 21) — тоже до автоконнекта,
  /// иначе первое TUN-подключение всё равно тормозит на ленивой конвертации.
  /// `_pingAllOnStartup()` не трогает дерево/выбор — безопасно не ждать.
  Future<void> _runStartupSequence() async {
    _pingAllOnStartup();
    await _autoRefreshSubscriptions();
    if (!mounted) return;
    await _ensureGeoAssets();
    if (!mounted) return;
    await _autoConnectOnStartup();
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
      final result = await refreshSubscription(
        subscription,
        autoGroup: autoGroup,
      );
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

  /// Только Windows — на Android этот же файл качает `FluxVpnService.kt`
  /// сам, отдельно, при старте туннеля (см. ROADMAP.md, трек 20).
  /// Best-effort и не блокирует UI — как и остальные вызовы в этом же
  /// `addPostFrameCallback`. После докачки сразу прогревает кэш rule-set'ов
  /// (`pregenerateGeoRuleSets`, трек 21) для категорий, уже встречающихся в
  /// текущих подписках — иначе первое подключение к TUN после (пере)установки
  /// само делает эту конвертацию и заметно тормозит (проверено — секунд
  /// пять на реальных файлах).
  Future<void> _ensureGeoAssets() async {
    if (!Platform.isWindows) return;
    final settings = ref.read(appSettingsProvider);
    await ensureGeoAssets(geoipUrl: settings.geoipUrl, geositeUrl: settings.geositeUrl);
    if (!mounted) return;
    // ensureGeoAssets — best-effort, сама не сообщает об успехе/неудаче
    // (см. её doc-комментарий) — единственный внешний способ узнать,
    // получилось ли, это проверить сами файлы после вызова. Не меняем её
    // сигнатуру ради одного уведомления — трек 25.
    if (!File(geoipFilePath()).existsSync() || !File(geositeFilePath()).existsSync()) {
      showFluxNotification(title: S.notificationGeoAssetsFailedTitle);
    }
    final allRoutingRules = [
      for (final leaf in flattenAllLeaves(ref.read(coreConfigProvider)))
        ...leaf.routingRules,
    ];
    await pregenerateGeoRuleSets(allRoutingRules);
  }

  /// Windows-only (ROADMAP.md, трек 24) — Android и так всегда TUN через
  /// VpnService, отдельного понятия автоподключения там нет. Вызывается
  /// последним в `_runStartupSequence()`, когда дерево серверов и
  /// `lastSelectedServerId` уже точно актуальны.
  Future<void> _autoConnectOnStartup() async {
    if (!Platform.isWindows) return;
    final settings = ref.read(appSettingsProvider);
    if (!settings.autoConnectOnStartup) return;

    final serverId = ref.read(selectedServerIdProvider);
    if (serverId == null) return;
    ServerLeaf? leaf;
    for (final candidate in flattenAllLeaves(ref.read(coreConfigProvider))) {
      if (candidate.id == serverId) {
        leaf = candidate;
        break;
      }
    }
    if (leaf == null) return;

    // Откат на Proxy, если elevated-автозапуск почему-то не сработал
    // (задачу удалили руками, UAC был отклонён и т.п.) — тихо, без ошибки:
    // `TunBridgeEngine.start()` и так бросил бы `StateError` без прав
    // администратора, но лучше подключиться в Proxy, чем не подключиться
    // вовсе.
    final mode = settings.autoConnectMode == ConnectionMode.tun && isRunningElevated()
        ? ConnectionMode.tun
        : ConnectionMode.proxy;

    // Реальный UI-фидбэк об ошибке подключения (в т.ч. при скрытом окне) уже
    // приходит отдельно — `connectToServer` сама переводит состояние в
    // `ConnectionError`, а `ConnectionNotifications` (трек 25, слушает
    // `connectionControllerProvider` глобально) на это шлёт тост. `catch`
    // ниже — просто страховка на случай синхронного исключения до самого
    // перехода состояния, не роняем экран из-за фонового автодействия при
    // старте.
    try {
      await ref
          .read(connectionControllerProvider.notifier)
          .connectToServer(leaf, mode: mode);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final homeBackground = settings.homeBackground;
    // customVideo без выбранного файла ведёт себя как none — юзер мог
    // переключиться на этот пункт в настройках, но ещё не выбрать видео.
    final showBackground =
        homeBackground != HomeBackground.none &&
        (homeBackground != HomeBackground.customVideo ||
            settings.customVideoPath != null);

    final mainContent = Stack(
      children: [
        if (showBackground)
          switch (homeBackground) {
            HomeBackground.none => const SizedBox.shrink(),
            HomeBackground.globe => Stack(
              children: [
                Positioned.fill(
                  child: Starfield(
                    color: PortColors.foreground,
                    rotation: _rotation,
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 620,
                      height: 620,
                      child: SphereGlobe(
                        color: PortColors.primary.withValues(alpha: 0.45),
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
              child: ShaderBackground(assetPath: 'shaders/color_bends.frag'),
            ),
            HomeBackground.galaxy => const Positioned.fill(
              child: ShaderBackground(assetPath: 'shaders/galaxy.frag'),
            ),
            HomeBackground.customVideo => Positioned.fill(
              child: VideoBackground(filePath: settings.customVideoPath!),
            ),
          },
        const ConnectPanel(),
      ],
    );

    return ColoredBox(
      color: PortColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Узкое окно (см. ROADMAP.md, трек 16) — правая часть (фон +
          // карточка подключения) становится главным экраном на весь
          // размер, список серверов вместо постоянной боковой колонки
          // прячется за кнопкой и открывается снизу листом
          // (`showPortBottomSheet`).
          if (constraints.maxWidth < kMobileBreakpoint) {
            final onOpenSettings = widget.onOpenSettings;
            // Без AppTitleBar (см. main.dart — его нет на Android) кнопки
            // висят прямо под системным статус-баром/чёлкой, если не
            // добавить его высоту явно — `mainContent` (фон/глобус) при этом
            // должен оставаться на весь экран, поэтому SafeArea оборачивает
            // только сами кнопки, а не весь Stack.
            final topInset = MediaQuery.of(context).padding.top + 12;
            // На Android эти две плавающие кнопки — единственный путь к
            // списку серверов/настройкам (нет бокового меню и AppTitleBar),
            // а дефолтный размер 36px под мышь на телефоне выглядит мелко —
            // увеличиваем и сам квадрат, и иконку внутри, только здесь.
            final buttonSize = Platform.isAndroid ? 44.0 : 36.0;
            final iconSize = Platform.isAndroid ? 20.0 : 16.0;
            return Stack(
              children: [
                mainContent,
                Positioned(
                  top: topInset,
                  left: 12,
                  child: PortIconButton.secondary(
                    icon: Icon(LucideIcons.list, size: iconSize),
                    size: buttonSize,
                    onPressed: () => openServerListSheet(context),
                  ),
                ),
                if (onOpenSettings != null)
                  Positioned(
                    top: topInset,
                    right: 12,
                    child: PortIconButton.secondary(
                      icon: Icon(LucideIcons.settings, size: iconSize),
                      size: buttonSize,
                      onPressed: onOpenSettings,
                    ),
                  ),
              ],
            );
          }

          return Row(
            children: [
              const ServerListPanel(),
              Expanded(child: mainContent),
            ],
          );
        },
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

    return [
      GlobeMarker(
        lat: centroid.$1,
        lon: centroid.$2,
        label: DecoratedBox(
          decoration: BoxDecoration(
            color: PortColors.popover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PortColors.border),
            boxShadow: [
              BoxShadow(
                color: PortColors.primary.withValues(alpha: 0.25),
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
                Text(leaf.name, style: PortText.small),
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
