import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_paths.dart';
import '../../app/layout_breakpoints.dart';
import '../../app/windows_autostart.dart';
import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/app_settings_provider.dart';
import '../../core_abstraction/core_config_provider.dart';
import '../../engines/geo_assets.dart';
import '../../engines/singbox/geo_ruleset_cache.dart';
import '../../l10n/strings.dart';
import '../../widgets/port_ui/port_ui.dart';
import '../servers/flatten_leaves.dart';
import 'about_info.dart';

enum _SettingsSection {
  personalization(LucideIcons.palette),
  ping(LucideIcons.activity),
  tun(LucideIcons.network),
  subscription(LucideIcons.rss),
  routing(LucideIcons.map),
  system(LucideIcons.settings),
  logs(LucideIcons.fileText),
  about(LucideIcons.info);

  final IconData icon;
  const _SettingsSection(this.icon);

  String get label => switch (this) {
    _SettingsSection.personalization => S.sectionPersonalization,
    _SettingsSection.ping => S.sectionPing,
    _SettingsSection.tun => 'TUN',
    _SettingsSection.subscription => S.sectionSubscription,
    _SettingsSection.routing => S.sectionRouting,
    _SettingsSection.system => S.sectionSystem,
    _SettingsSection.logs => S.sectionLogs,
    _SettingsSection.about => S.sectionAbout,
  };
}

/// На Android нет ни автозапуска через реестр (`_SettingsSection.system`
/// — `setAutoStartOnBoot` там тихо no-op), ни выбора TUN-ядра
/// (`_SettingsSection.tun` — там всегда sing-box-специфичный список, а
/// Android использует собственный `tun`-инбаунд xray-core, не sing-box
/// вовсе, см. `xray_engine_android.dart`) — обе секции только путали бы.
List<_SettingsSection> get _visibleSettingsSections => Platform.isAndroid
    ? _SettingsSection.values
          .where(
            (s) => s != _SettingsSection.tun && s != _SettingsSection.system,
          )
          .toList()
    : _SettingsSection.values;

/// Настройки приложения — отдельная страница (заменяет `home` вместо
/// `ConnectionScreen`, см. `FluxApp`), а не диалог: список секций разросся
/// настолько, что диалог по центру окна уже не помещался по высоте.
/// Секции разложены по менюшке слева (как ServerListPanel) вместо одного
/// длинного скролла — иначе тяжело найти нужный контрол среди полутора
/// десятков.
/// Каждый контрол применяется и сохраняется сразу же, без отдельной кнопки
/// "Сохранить" — как остальные тумблеры в приложении (см. OffProxyTunSelector).
class SettingsPage extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const SettingsPage({super.key, required this.onBack});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _SettingsSection _section = _SettingsSection.personalization;
  bool _updatingGeoAssets = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final mobile = isMobileLayout(context);

    // Без AppTitleBar (см. main.dart — его нет на Android) эта шапка сама
    // становится первым, что рисуется сверху — SafeArea защищает её от
    // статус-бара/чёлки, снаружи (не нужен на Windows: там всегда padding.top
    // == 0, SafeArea там no-op).
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: PortColors.border)),
            ),
            child: Row(
              children: [
                PortIconButton.ghost(
                  icon: const Icon(LucideIcons.arrowLeft),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
                Text(S.settingsTitle, style: PortText.large),
              ],
            ),
          ),
          Expanded(
            child: mobile
                ? _buildMobileBody(settings, notifier)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingsNav(
                        sections: _visibleSettingsSections,
                        selected: _section,
                        onSelect: (section) =>
                            setState(() => _section = section),
                      ),
                      Expanded(
                        child: _buildSectionScroll(
                          _section,
                          settings,
                          notifier,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Мобильная раскладка — нав (200px) и контент (`maxWidth: 480`) рядом не
  /// помещаются на узких окнах (см. ROADMAP.md, трек 16). Раньше вместо
  /// бокового меню показывался список секций на весь экран, потом отдельная
  /// страница с открытой секцией и своей мини-шапкой "назад к списку" — два
  /// заголовка друг над другом (внешний "Settings" + внутренний с именем
  /// секции) и свой самодельный back-стек в state, который не слушал ни
  /// системную кнопку "назад", ни жест. Заменили на горизонтальный ряд
  /// вкладок (`PortTabsList`, порт shadcn Tabs — см. docs/internal/shadcn/
  /// PLAN.md) сверху и контент секции сразу под ним, без второй страницы —
  /// один экран, одна шапка. Системная кнопка/жест "назад" на Android,
  /// закрывающие теперь Settings целиком — отдельная поломка на уровне
  /// выше, см. `PopScope` в `main.dart`, `_FluxAppState.build`.
  Widget _buildMobileBody(
    AppSettings settings,
    AppSettingsController notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: PortTabsList<_SettingsSection>(
            value: _section,
            items: [
              for (final section in _visibleSettingsSections)
                PortTabItem(
                  value: section,
                  leading: Icon(section.icon, size: 14),
                  child: Text(section.label),
                ),
            ],
            onChanged: (section) => setState(() => _section = section),
          ),
        ),
        Expanded(child: _buildSectionScroll(_section, settings, notifier)),
      ],
    );
  }

  /// Скроллящаяся обёртка над [_buildSection] — общая для десктопной панели
  /// и мобильной детальной раскладки.
  Widget _buildSectionScroll(
    _SettingsSection section,
    AppSettings settings,
    AppSettingsController notifier,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        // key заставляет Flutter пересоздавать поддерево целиком при смене
        // секции вместо переиспользования Element на совпадающей позиции —
        // без него, например, PortInput без своего ключа на одной и той же
        // позиции в дереве (URL пинга в «Пинге», DNS-сервер в «TUN») делил
        // один и тот же State/TextEditingController между секциями: typing
        // в одном поле отражался в другом при переключении вкладки.
        child: KeyedSubtree(
          key: ValueKey(section),
          child: _buildSection(section, settings, notifier),
        ),
      ),
    );
  }

  Widget _buildSection(
    _SettingsSection section,
    AppSettings settings,
    AppSettingsController notifier,
  ) {
    return switch (section) {
      _SettingsSection.personalization => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingRow(
            label: S.themeLabel,
            // Залочено на Dark — светлая палитра ещё не доведена (см.
            // ROADMAP.md, трек 18; main.dart, PortBrightness.current
            // хардкожен в Brightness.dark независимо от этой настройки).
            // System/Light временно убраны из списка вариантов — тот же
            // приём, что и у "Ядро TUN-режима" ниже, где вариант тоже пока
            // единственный.
            child: PortSelect<AppThemeMode>(
              initialValue: AppThemeMode.dark,
              onChanged: (value) {
                if (value != null) {
                  notifier.update((s) => s.copyWith(themeMode: value));
                }
              },
              options: [
                PortSelectOption(
                  value: AppThemeMode.dark,
                  child: Text(S.themeDark),
                ),
              ],
              selectedOptionBuilder: (context, value) =>
                  Text(_themeModeLabel(value)),
            ),
          ),
          const SizedBox(height: 12),
          _SettingRow(
            label: S.languageLabel,
            child: PortSelect<AppLanguage>(
              initialValue: settings.language,
              onChanged: (value) {
                if (value != null) {
                  notifier.update((s) => s.copyWith(language: value));
                }
              },
              // Названия языков всегда на своём родном языке (не через S) —
              // так принято в language-переключателях, не зависит от того,
              // на каком языке сейчас сам интерфейс.
              options: [
                PortSelectOption(
                  value: AppLanguage.system,
                  child: Text(S.languageSystem),
                ),
                const PortSelectOption(
                  value: AppLanguage.ru,
                  child: Text('Русский'),
                ),
                const PortSelectOption(
                  value: AppLanguage.en,
                  child: Text('English'),
                ),
              ],
              selectedOptionBuilder: (context, value) =>
                  Text(_languageLabel(value)),
            ),
          ),
          const SizedBox(height: 12),
          _SettingRow(
            label: S.homeBackgroundLabel,
            child: PortSelect<HomeBackground>(
              initialValue: settings.homeBackground,
              onChanged: (value) {
                if (value != null) {
                  notifier.update((s) => s.copyWith(homeBackground: value));
                }
              },
              options: [
                PortSelectOption(
                  value: HomeBackground.none,
                  child: Text(S.backgroundNone),
                ),
                PortSelectOption(
                  value: HomeBackground.globe,
                  child: Text(S.backgroundGlobe),
                ),
                const PortSelectOption(
                  value: HomeBackground.simpleGradient,
                  child: Text('Simple Gradient'),
                ),
                const PortSelectOption(
                  value: HomeBackground.colorBends,
                  child: Text('Color Bends'),
                ),
                const PortSelectOption(
                  value: HomeBackground.galaxy,
                  child: Text('Galaxy'),
                ),
              ],
              selectedOptionBuilder: (context, value) =>
                  Text(_homeBackgroundLabel(value)),
            ),
          ),
        ],
      ),
      _SettingsSection.ping => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingRow(
            label: S.checkMethodLabel,
            child: PortSelect<PingMode>(
              initialValue: settings.pingMode,
              onChanged: (value) {
                if (value != null) {
                  notifier.update((s) => s.copyWith(pingMode: value));
                }
              },
              options: [
                PortSelectOption(
                  value: PingMode.viaProxy,
                  child: Text(S.throughProxy),
                ),
                const PortSelectOption(value: PingMode.tcp, child: Text('TCP')),
                const PortSelectOption(
                  value: PingMode.icmp,
                  child: Text('ICMP'),
                ),
              ],
              selectedOptionBuilder: (context, value) =>
                  Text(_pingModeLabel(value)),
            ),
          ),
          const SizedBox(height: 12),
          Text(S.checkUrlLabel, style: PortText.small),
          const SizedBox(height: 6),
          PortInput(
            initialValue: settings.pingTestUrl,
            placeholder: 'https://www.gstatic.com/generate_204',
            onSubmitted: (value) {
              final url = value.trim();
              notifier.update(
                (s) => s.copyWith(
                  pingTestUrl: url.isEmpty
                      ? 'https://www.gstatic.com/generate_204'
                      : url,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          PortSwitch(
            value: settings.pingAllOnStartup,
            label: Text(S.pingAllOnStartupLabel),
            onChanged: (value) =>
                notifier.update((s) => s.copyWith(pingAllOnStartup: value)),
          ),
        ],
      ),
      _SettingsSection.tun => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingRow(
            label: S.tunCoreLabel,
            child: PortSelect<TunCoreType>(
              initialValue: settings.tunCoreType,
              onChanged: (value) {
                if (value != null) {
                  notifier.update((s) => s.copyWith(tunCoreType: value));
                }
              },
              options: const [
                PortSelectOption(
                  value: TunCoreType.singBox,
                  child: Text('sing-box'),
                ),
              ],
              selectedOptionBuilder: (context, value) =>
                  Text(_tunCoreTypeLabel(value)),
            ),
          ),
          const SizedBox(height: 12),
          Text(S.tunDnsLabel, style: PortText.small),
          const SizedBox(height: 6),
          PortInput(
            initialValue: settings.tunDnsServer,
            placeholder: defaultTunDnsServer,
            onSubmitted: (value) {
              final server = value.trim();
              notifier.update(
                (s) => s.copyWith(
                  tunDnsServer: server.isEmpty ? defaultTunDnsServer : server,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          // Ручка «DNS для прокси» отсутствует не по недосмотру: в
          // Proxy-режиме xray домены не резолвит вообще, а передаёт
          // серверу, который резолвит их у себя.
          Text(
            S.proxyDnsNote,
            style: PortText.small.copyWith(color: PortColors.mutedForeground),
          ),
        ],
      ),
      _SettingsSection.subscription => PortSwitch(
        value: settings.autoGroupSubscriptions,
        label: Text(S.autoGroupLabel),
        onChanged: (value) =>
            notifier.update((s) => s.copyWith(autoGroupSubscriptions: value)),
      ),
      _SettingsSection.routing => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(S.geoipUrlLabel, style: PortText.small),
          const SizedBox(height: 6),
          PortInput(
            initialValue: settings.geoipUrl,
            placeholder: defaultGeoipUrl,
            onSubmitted: (value) {
              final url = value.trim();
              notifier.update(
                (s) => s.copyWith(geoipUrl: url.isEmpty ? defaultGeoipUrl : url),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(S.geositeUrlLabel, style: PortText.small),
          const SizedBox(height: 6),
          PortInput(
            initialValue: settings.geositeUrl,
            placeholder: defaultGeositeUrl,
            onSubmitted: (value) {
              final url = value.trim();
              notifier.update(
                (s) =>
                    s.copyWith(geositeUrl: url.isEmpty ? defaultGeositeUrl : url),
              );
            },
          ),
          const SizedBox(height: 12),
          PortButton.outline(
            leading: const Icon(LucideIcons.refreshCw, size: 16),
            onPressed: _updatingGeoAssets
                ? null
                : () => _updateGeoAssets(context, settings),
            child: Text(_updatingGeoAssets ? '…' : S.updateGeoAssetsLabel),
          ),
        ],
      ),
      _SettingsSection.system => PortSwitch(
        value: settings.autoStartOnBoot,
        label: Text(S.autoStartLabel),
        onChanged: (value) {
          setAutoStartOnBoot(value);
          notifier.update((s) => s.copyWith(autoStartOnBoot: value));
        },
      ),
      _SettingsSection.logs => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingRow(
            label: S.verbosityLabel,
            child: PortSelect<CoreLogLevel>(
              initialValue: settings.coreLogLevel,
              onChanged: (value) {
                if (value != null) {
                  notifier.update((s) => s.copyWith(coreLogLevel: value));
                }
              },
              options: [
                PortSelectOption(
                  value: CoreLogLevel.error,
                  child: Text(S.logErrorsOnly),
                ),
                PortSelectOption(
                  value: CoreLogLevel.warn,
                  child: Text(S.logWarnings),
                ),
                PortSelectOption(
                  value: CoreLogLevel.info,
                  child: Text(S.logDetailed),
                ),
                PortSelectOption(
                  value: CoreLogLevel.debug,
                  child: Text(S.logDebug),
                ),
              ],
              selectedOptionBuilder: (context, value) =>
                  Text(_logLevelLabel(value)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S.logLevelNote,
            style: PortText.small.copyWith(color: PortColors.mutedForeground),
          ),
          const SizedBox(height: 10),
          PortButton.outline(
            leading: const Icon(LucideIcons.folderOpen, size: 16),
            onPressed: openFluxLogDirectory,
            child: Text(S.openLogsFolder),
          ),
        ],
      ),
      _SettingsSection.about => const _AboutSection(),
    };
  }

  Future<void> _updateGeoAssets(BuildContext context, AppSettings settings) async {
    setState(() => _updatingGeoAssets = true);
    try {
      await forceUpdateGeoAssets(
        geoipUrl: settings.geoipUrl,
        geositeUrl: settings.geositeUrl,
      );
      // Прогрев кэша rule-set'ов сразу после обновления баз (трек 21) — иначе
      // первое подключение к TUN само делает конвертацию и заметно тормозит.
      final allRoutingRules = [
        for (final leaf in flattenAllLeaves(ref.read(coreConfigProvider)))
          ...leaf.routingRules,
      ];
      await pregenerateGeoRuleSets(allRoutingRules);
      if (!context.mounted) return;
      PortToaster.of(context).show(PortToast(title: Text(S.geoAssetsUpdateSuccess)));
    } catch (e) {
      if (!context.mounted) return;
      PortToaster.of(
        context,
      ).show(PortToast(title: Text(S.geoAssetsUpdateFailure(e))));
    } finally {
      if (mounted) setState(() => _updatingGeoAssets = false);
    }
  }

  String _themeModeLabel(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => S.themeSystem,
    AppThemeMode.light => S.themeLight,
    AppThemeMode.dark => S.themeDark,
  };

  // Русский/English — родные названия языков, не переводятся через S (см.
  // комментарий у селектора выше).
  String _languageLabel(AppLanguage language) => switch (language) {
    AppLanguage.system => S.languageSystem,
    AppLanguage.ru => 'Русский',
    AppLanguage.en => 'English',
  };

  String _homeBackgroundLabel(HomeBackground bg) => switch (bg) {
    HomeBackground.none => S.backgroundNone,
    HomeBackground.globe => S.backgroundGlobe,
    HomeBackground.simpleGradient => 'Simple Gradient',
    HomeBackground.colorBends => 'Color Bends',
    HomeBackground.galaxy => 'Galaxy',
  };

  String _pingModeLabel(PingMode mode) => switch (mode) {
    PingMode.viaProxy => S.throughProxy,
    PingMode.tcp => 'TCP',
    PingMode.icmp => 'ICMP',
  };

  String _tunCoreTypeLabel(TunCoreType type) => switch (type) {
    TunCoreType.singBox => 'sing-box',
  };

  String _logLevelLabel(CoreLogLevel level) => switch (level) {
    CoreLogLevel.error => S.logErrorsOnly,
    CoreLogLevel.warn => S.logWarnings,
    CoreLogLevel.info => S.logDetailed,
    CoreLogLevel.debug => S.logDebug,
  };
}

class _SettingsNav extends StatelessWidget {
  final List<_SettingsSection> sections;
  final _SettingsSection selected;
  final ValueChanged<_SettingsSection> onSelect;

  const _SettingsNav({
    required this.sections,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: PortColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in sections)
            _SettingsNavItem(
              section: section,
              selected: section == selected,
              onTap: () => onSelect(section),
            ),
        ],
      ),
    );
  }
}

class _SettingsNavItem extends StatefulWidget {
  final _SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsNavItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SettingsNavItem> createState() => _SettingsNavItemState();
}

class _SettingsNavItemState extends State<_SettingsNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.selected
        ? PortColors.accent
        : _hovered
        ? PortColors.accent.withValues(alpha: 0.5)
        : const Color(0x00000000);
    final foreground = widget.selected
        ? PortColors.foreground
        : PortColors.mutedForeground;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.section.icon, size: 16, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.section.label,
                  style: PortText.small.copyWith(height: 1, color: foreground),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Версии приложения и ядер. Пока не загрузились — показываем прочерки, а не
/// спиннер: строк мало, они узкие, и мигание скелетоном тут заметнее самих
/// данных.
class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(aboutInfoProvider);

    final infoRows = switch (info) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AboutRow('Flux', _appVersionText(value)),
          _AboutRow(S.built, _buildDateText(value.builtAt)),
          _AboutRow('xray-core', value.xrayVersion ?? S.notFound),
          _AboutRow('sing-box', value.singBoxVersion ?? S.notFound),
        ],
      ),
      AsyncError() => _AboutRow(S.versionsLabel, S.couldNotDetermine),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AboutRow('Flux', '—'),
          _AboutRow(S.built, '—'),
          const _AboutRow('xray-core', '—'),
          const _AboutRow('sing-box', '—'),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        infoRows,
        const SizedBox(height: 16),
        // Сбрасывает только сам флаг (`onboardingCompleted: false`) — сам
        // визард ничего не знает про "запущено из настроек" vs "первый
        // запуск", main.dart реактивно подменит эту же SettingsPage на
        // OnboardingFlow при следующей перестройке (см. main.dart).
        PortButton.outline(
          onPressed: () => ref
              .read(appSettingsProvider.notifier)
              .update((s) => s.copyWith(onboardingCompleted: false)),
          leading: const Icon(LucideIcons.compass, size: 14),
          child: Text(S.redoOnboardingLabel),
        ),
      ],
    );
  }

  String _appVersionText(AboutInfo info) => info.buildNumber.isEmpty
      ? info.appVersion
      : '${info.appVersion} (${S.buildNumberSuffix(info.buildNumber)})';

  String _buildDateText(DateTime? builtAt) {
    if (builtAt == null) return S.unknown;
    final local = builtAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: PortText.small.copyWith(color: PortColors.mutedForeground),
            ),
          ),
          Text(value, style: PortText.small),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _SettingRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    // На мобильной раскладке ярлык + `PortSelect` (свой minWidth: 140) в
    // одном Row не помещаются на узких окнах (см. ROADMAP.md, трек 16) —
    // вместо переполнения ставим селект под ярлыком.
    if (isMobileLayout(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PortText.p),
          const SizedBox(height: 6),
          child,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: Text(label, style: PortText.p)),
        child,
      ],
    );
  }
}
