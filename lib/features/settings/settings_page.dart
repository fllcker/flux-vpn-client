import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_paths.dart';
import '../../app/windows_autostart.dart';
import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/app_settings_provider.dart';
import '../../widgets/port_ui/port_ui.dart';
import 'about_info.dart';

enum _SettingsSection {
  personalization('Персонализация', LucideIcons.palette),
  ping('Пинг', LucideIcons.activity),
  tun('TUN', LucideIcons.network),
  subscription('Подписка', LucideIcons.rss),
  system('Система', LucideIcons.settings),
  logs('Логи', LucideIcons.fileText),
  about('О программе', LucideIcons.info);

  final String label;
  final IconData icon;
  const _SettingsSection(this.label, this.icon);
}

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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PortColors.border)),
          ),
          child: Row(
            children: [
              PortIconButton.ghost(icon: const Icon(LucideIcons.arrowLeft), onPressed: widget.onBack),
              const SizedBox(width: 8),
              Text('Настройки', style: PortText.large),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsNav(
                selected: _section,
                onSelect: (section) => setState(() => _section = section),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildSection(_section, settings, notifier),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
            label: 'Тема',
            child: PortSelect<AppThemeMode>(
              initialValue: settings.themeMode,
              onChanged: (value) {
                if (value != null) {
                  notifier.update((s) => s.copyWith(themeMode: value));
                }
              },
              options: const [
                PortSelectOption(value: AppThemeMode.system, child: Text('Системная')),
                PortSelectOption(value: AppThemeMode.light, child: Text('Светлая')),
                PortSelectOption(value: AppThemeMode.dark, child: Text('Тёмная')),
              ],
              selectedOptionBuilder: (context, value) => Text(_themeModeLabel(value)),
            ),
          ),
          const SizedBox(height: 6),
          // Настройка сохраняется, но пока ни на что не влияет — светлая
          // тема ещё не портирована (см. ROADMAP.md, трек 10). Явная
          // пометка вместо тихой заглушки, чтобы не создавать у
          // пользователя ложное ожидание от переключателя.
          Text(
            'Пока без эффекта — приложение всегда в тёмной теме, '
            'светлая ещё в разработке.',
            style: PortText.small.copyWith(color: PortColors.mutedForeground),
          ),
          const SizedBox(height: 12),
          _SettingRow(
            label: 'Фон на главной',
            child: PortSelect<HomeBackground>(
              initialValue: settings.homeBackground,
              onChanged: (value) {
                if (value != null) {
                  notifier.update((s) => s.copyWith(homeBackground: value));
                }
              },
              options: const [
                PortSelectOption(value: HomeBackground.none, child: Text('Нет')),
                PortSelectOption(value: HomeBackground.globe, child: Text('Планета')),
                PortSelectOption(
                  value: HomeBackground.simpleGradient,
                  child: Text('Simple Gradient'),
                ),
                PortSelectOption(
                  value: HomeBackground.colorBends,
                  child: Text('Color Bends'),
                ),
                PortSelectOption(value: HomeBackground.galaxy, child: Text('Galaxy')),
              ],
              selectedOptionBuilder: (context, value) => Text(_homeBackgroundLabel(value)),
            ),
          ),
        ],
      ),
      _SettingsSection.ping => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingRow(
            label: 'Способ проверки',
            child: PortSelect<PingMode>(
              initialValue: settings.pingMode,
              onChanged: (value) {
                if (value != null) {
                  notifier.update((s) => s.copyWith(pingMode: value));
                }
              },
              options: const [
                PortSelectOption(value: PingMode.viaProxy, child: Text('Через прокси')),
                PortSelectOption(value: PingMode.tcp, child: Text('TCP')),
                PortSelectOption(value: PingMode.icmp, child: Text('ICMP')),
              ],
              selectedOptionBuilder: (context, value) => Text(_pingModeLabel(value)),
            ),
          ),
          const SizedBox(height: 12),
          Text('URL для проверки (через прокси)', style: PortText.small),
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
            label: const Text('Пинговать все серверы при открытии'),
            onChanged: (value) =>
                notifier.update((s) => s.copyWith(pingAllOnStartup: value)),
          ),
        ],
      ),
      _SettingsSection.tun => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingRow(
            label: 'Ядро TUN-режима',
            child: PortSelect<TunCoreType>(
              initialValue: settings.tunCoreType,
              onChanged: (value) {
                if (value != null) {
                  notifier.update((s) => s.copyWith(tunCoreType: value));
                }
              },
              options: const [
                PortSelectOption(value: TunCoreType.singBox, child: Text('sing-box')),
              ],
              selectedOptionBuilder: (context, value) => Text(_tunCoreTypeLabel(value)),
            ),
          ),
          const SizedBox(height: 12),
          Text('DNS-сервер (только TUN)', style: PortText.small),
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
            'Адресом, а не именем — резолвить сам резолвер было бы '
            'замкнутым кругом. В Proxy-режиме имена резолвит сервер, '
            'поэтому настройка на него не влияет.',
            style: PortText.small.copyWith(color: PortColors.mutedForeground),
          ),
        ],
      ),
      _SettingsSection.subscription => PortSwitch(
        value: settings.autoGroupSubscriptions,
        label: const Text('Автоматическая разбивка по группам'),
        onChanged: (value) =>
            notifier.update((s) => s.copyWith(autoGroupSubscriptions: value)),
      ),
      _SettingsSection.system => PortSwitch(
        value: settings.autoStartOnBoot,
        label: const Text('Запускать при старте Windows'),
        onChanged: (value) {
          setAutoStartOnBoot(value);
          notifier.update((s) => s.copyWith(autoStartOnBoot: value));
        },
      ),
      _SettingsSection.logs => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingRow(
            label: 'Подробность',
            child: PortSelect<CoreLogLevel>(
              initialValue: settings.coreLogLevel,
              onChanged: (value) {
                if (value != null) {
                  notifier.update((s) => s.copyWith(coreLogLevel: value));
                }
              },
              options: const [
                PortSelectOption(value: CoreLogLevel.error, child: Text('Только ошибки')),
                PortSelectOption(value: CoreLogLevel.warn, child: Text('Предупреждения')),
                PortSelectOption(value: CoreLogLevel.info, child: Text('Подробно')),
                PortSelectOption(value: CoreLogLevel.debug, child: Text('Отладка')),
              ],
              selectedOptionBuilder: (context, value) => Text(_logLevelLabel(value)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Уровень применяется при следующем подключении. На «Отладке» '
            'видно каждое соединение и решения роутинга — этим и '
            'разбираются проблемы TUN, но лог растёт на сотни килобайт '
            'за минуты.',
            style: PortText.small.copyWith(color: PortColors.mutedForeground),
          ),
          const SizedBox(height: 10),
          PortButton.outline(
            leading: const Icon(LucideIcons.folderOpen, size: 16),
            onPressed: openFluxLogDirectory,
            child: const Text('Открыть папку с логами'),
          ),
        ],
      ),
      _SettingsSection.about => const _AboutSection(),
    };
  }

  String _themeModeLabel(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => 'Системная',
    AppThemeMode.light => 'Светлая',
    AppThemeMode.dark => 'Тёмная',
  };

  String _homeBackgroundLabel(HomeBackground bg) => switch (bg) {
    HomeBackground.none => 'Нет',
    HomeBackground.globe => 'Планета',
    HomeBackground.simpleGradient => 'Simple Gradient',
    HomeBackground.colorBends => 'Color Bends',
    HomeBackground.galaxy => 'Galaxy',
  };

  String _pingModeLabel(PingMode mode) => switch (mode) {
    PingMode.viaProxy => 'Через прокси',
    PingMode.tcp => 'TCP',
    PingMode.icmp => 'ICMP',
  };

  String _tunCoreTypeLabel(TunCoreType type) => switch (type) {
    TunCoreType.singBox => 'sing-box',
  };

  String _logLevelLabel(CoreLogLevel level) => switch (level) {
    CoreLogLevel.error => 'Только ошибки',
    CoreLogLevel.warn => 'Предупреждения',
    CoreLogLevel.info => 'Подробно',
    CoreLogLevel.debug => 'Отладка',
  };
}

class _SettingsNav extends StatelessWidget {
  final _SettingsSection selected;
  final ValueChanged<_SettingsSection> onSelect;

  const _SettingsNav({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: PortColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in _SettingsSection.values)
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

    return switch (info) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AboutRow('Flux', _appVersionText(value)),
          _AboutRow('Собрано', _buildDateText(value.builtAt)),
          _AboutRow('xray-core', value.xrayVersion ?? 'не найден'),
          _AboutRow('sing-box', value.singBoxVersion ?? 'не найден'),
        ],
      ),
      AsyncError() => const _AboutRow('Версии', 'не удалось определить'),
      _ => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AboutRow('Flux', '—'),
          _AboutRow('Собрано', '—'),
          _AboutRow('xray-core', '—'),
          _AboutRow('sing-box', '—'),
        ],
      ),
    };
  }

  String _appVersionText(AboutInfo info) =>
      info.buildNumber.isEmpty
      ? info.appVersion
      : '${info.appVersion} (сборка ${info.buildNumber})';

  String _buildDateText(DateTime? builtAt) {
    if (builtAt == null) return 'неизвестно';
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
    return Row(
      children: [
        Expanded(child: Text(label, style: PortText.p)),
        child,
      ],
    );
  }
}
