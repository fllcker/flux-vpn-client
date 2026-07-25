import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/dialog_style.dart';
import '../../app/windows_autostart.dart';
import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/app_settings_provider.dart';
import '../../widgets/port_ui/port_ui.dart';

/// Настройки приложения — центрированный диалог с тремя разделами:
/// персонализация, пинг, подписки. Каждый контрол применяется и сохраняется
/// сразу же, без отдельной кнопки "Сохранить" — как остальные тумблеры в
/// приложении (см. OffProxyTunSelector).
class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return PortDialog(
      title: const Text('Настройки'),
      child: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SectionLabel('Персонализация'),
            const SizedBox(height: 10),
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
                selectedOptionBuilder: (context, value) =>
                    Text(_themeModeLabel(value)),
              ),
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
                selectedOptionBuilder: (context, value) =>
                    Text(_homeBackgroundLabel(value)),
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Пинг'),
            const SizedBox(height: 10),
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
                selectedOptionBuilder: (context, value) =>
                    Text(_pingModeLabel(value)),
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
            const SizedBox(height: 20),
            const _SectionLabel('TUN'),
            const SizedBox(height: 10),
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
                selectedOptionBuilder: (context, value) =>
                    Text(_tunCoreTypeLabel(value)),
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Подписка'),
            const SizedBox(height: 10),
            PortSwitch(
              value: settings.autoGroupSubscriptions,
              label: const Text('Автоматическая разбивка по группам'),
              onChanged: (value) =>
                  notifier.update((s) => s.copyWith(autoGroupSubscriptions: value)),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Система'),
            const SizedBox(height: 10),
            PortSwitch(
              value: settings.autoStartOnBoot,
              label: const Text('Запускать при старте Windows'),
              onChanged: (value) {
                setAutoStartOnBoot(value);
                notifier.update((s) => s.copyWith(autoStartOnBoot: value));
              },
            ),
          ],
        ),
      ),
    );
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: PortText.small.copyWith(
        fontWeight: FontWeight.w600,
        color: PortColors.mutedForeground,
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

/// Показывает диалог настроек по центру окна.
Future<void> showSettingsDialog(BuildContext context) {
  return showPortDialog(
    context: context,
    barrierColor: dialogBarrierColor,
    builder: (_) => const SettingsDialog(),
  );
}
