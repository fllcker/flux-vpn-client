import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/dialog_style.dart';
import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/app_settings_provider.dart';

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

    return ShadDialog(
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
              child: ShadSelect<AppThemeMode>(
                initialValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    notifier.update((s) => s.copyWith(themeMode: value));
                  }
                },
                options: const [
                  ShadOption(value: AppThemeMode.system, child: Text('Системная')),
                  ShadOption(value: AppThemeMode.light, child: Text('Светлая')),
                  ShadOption(value: AppThemeMode.dark, child: Text('Тёмная')),
                ],
                selectedOptionBuilder: (context, value) =>
                    Text(_themeModeLabel(value)),
              ),
            ),
            const SizedBox(height: 12),
            _SettingRow(
              label: 'Фон на главной',
              child: ShadSelect<HomeBackground>(
                initialValue: settings.homeBackground,
                onChanged: (value) {
                  if (value != null) {
                    notifier.update((s) => s.copyWith(homeBackground: value));
                  }
                },
                options: const [
                  ShadOption(value: HomeBackground.none, child: Text('Нет')),
                  ShadOption(value: HomeBackground.globe, child: Text('Планета')),
                  ShadOption(
                    value: HomeBackground.simpleGradient,
                    child: Text('Simple Gradient'),
                  ),
                  ShadOption(
                    value: HomeBackground.colorBends,
                    child: Text('Color Bends'),
                  ),
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
              child: ShadSelect<PingMode>(
                initialValue: settings.pingMode,
                onChanged: (value) {
                  if (value != null) {
                    notifier.update((s) => s.copyWith(pingMode: value));
                  }
                },
                options: const [
                  ShadOption(value: PingMode.viaProxy, child: Text('Через прокси')),
                  ShadOption(value: PingMode.tcp, child: Text('TCP')),
                  ShadOption(value: PingMode.icmp, child: Text('ICMP')),
                ],
                selectedOptionBuilder: (context, value) =>
                    Text(_pingModeLabel(value)),
              ),
            ),
            const SizedBox(height: 12),
            Text('URL для проверки (через прокси)', style: ShadTheme.of(context).textTheme.small),
            const SizedBox(height: 6),
            ShadInput(
              initialValue: settings.pingTestUrl,
              placeholder: const Text('https://www.gstatic.com/generate_204'),
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
            ShadSwitch(
              value: settings.pingAllOnStartup,
              label: const Text('Пинговать все серверы при открытии'),
              onChanged: (value) =>
                  notifier.update((s) => s.copyWith(pingAllOnStartup: value)),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Подписка'),
            const SizedBox(height: 10),
            ShadSwitch(
              value: settings.autoGroupSubscriptions,
              label: const Text('Автоматическая разбивка по группам'),
              onChanged: (value) =>
                  notifier.update((s) => s.copyWith(autoGroupSubscriptions: value)),
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
  };

  String _pingModeLabel(PingMode mode) => switch (mode) {
    PingMode.viaProxy => 'Через прокси',
    PingMode.tcp => 'TCP',
    PingMode.icmp => 'ICMP',
  };
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Text(
      text,
      style: theme.textTheme.small.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.mutedForeground,
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
    final theme = ShadTheme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.p)),
        child,
      ],
    );
  }
}

/// Показывает диалог настроек по центру окна.
Future<void> showSettingsDialog(BuildContext context) {
  return showShadDialog(
    context: context,
    barrierColor: dialogBarrierColor,
    opaque: false,
    builder: (_) => const SettingsDialog(),
  );
}
