import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/layout_breakpoints.dart';
import '../../app/windows_autostart.dart';
import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/app_settings_provider.dart';
import '../../core_abstraction/core_config_provider.dart' show standaloneParentId;
import '../../core_abstraction/proxy_node.dart';
import '../../l10n/strings.dart';
import '../../widgets/globe/shader_background.dart';
import '../../widgets/globe/sphere_globe.dart';
import '../../widgets/globe/starfield.dart';
import '../../widgets/port_ui/port_ui.dart';
import '../servers/proxy_tree_list.dart';
import 'onboarding_demo_data.dart';

/// Шаг 0 — выбор "настроить" (пройти остальные шаги) или "пропустить"
/// (сразу на главный экран с текущими/дефолтными значениями). Ту же кнопку
/// "Пропустить", маленькую, `OnboardingFlow` держит поверх всех
/// последующих шагов — см. её doc-комментарий.
class WelcomeStep extends StatelessWidget {
  final VoidCallback onCustomize;
  final VoidCallback onSkip;

  const WelcomeStep({super.key, required this.onCustomize, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(S.onboardingWelcomeTitle, style: PortText.h4, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          S.onboardingWelcomeSubtitle,
          style: PortText.muted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        PortButton(onPressed: onCustomize, child: Text(S.onboardingCustomize)),
        const SizedBox(height: 8),
        PortButton.ghost(onPressed: onSkip, child: Text(S.onboardingSkip)),
      ],
    );
  }
}

/// Шаг "Фон" — сетка маленьких карточек, в каждой реально рендерится сам
/// фон в изоляции (тот же `Starfield`/`SphereGlobe`/`ShaderBackground`, что
/// и на главном экране, `connection_screen.dart`, только без
/// глобус-маркеров/ротации, привязанных к выбранному серверу — тут это не
/// нужно, превью не должно ничего знать о реальных данных).
class BackgroundStep extends ConsumerWidget {
  const BackgroundStep({super.key});

  static const _options = HomeBackground.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(S.onboardingBackgroundTitle, style: PortText.h4, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final option in _options)
              _BackgroundPreviewCard(
                value: option,
                selected: settings.homeBackground == option,
                onTap: () => notifier.update((s) => s.copyWith(homeBackground: option)),
              ),
          ],
        ),
      ],
    );
  }
}

class _BackgroundPreviewCard extends StatelessWidget {
  final HomeBackground value;
  final bool selected;
  final VoidCallback onTap;

  const _BackgroundPreviewCard({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  // Те же подписи, что и в settings_page.dart ("Фон на главной") — не
  // дублируем локализацию, `simpleGradient`/`colorBends`/`galaxy` там тоже
  // пока английские литералы.
  String get _label => switch (value) {
    HomeBackground.none => S.backgroundNone,
    HomeBackground.globe => S.backgroundGlobe,
    HomeBackground.simpleGradient => 'Simple Gradient',
    HomeBackground.colorBends => 'Color Bends',
    HomeBackground.galaxy => 'Galaxy',
  };

  Widget get _preview => switch (value) {
    HomeBackground.none => ColoredBox(color: PortColors.background),
    HomeBackground.globe => Stack(
      fit: StackFit.expand,
      children: [
        Starfield(color: PortColors.foreground),
        Center(
          child: SizedBox(
            width: 72,
            height: 72,
            child: SphereGlobe(
              color: PortColors.primary.withValues(alpha: 0.45),
              markers: const [],
            ),
          ),
        ),
      ],
    ),
    HomeBackground.simpleGradient => const ShaderBackground(
      assetPath: 'shaders/simple_gradient.frag',
    ),
    HomeBackground.colorBends => const ShaderBackground(
      assetPath: 'shaders/color_bends.frag',
    ),
    HomeBackground.galaxy => const ShaderBackground(assetPath: 'shaders/galaxy.frag'),
  };

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            // Рамка и клип контента — намеренно РАЗНЫЕ прямоугольники, не
            // Border.all+clipBehavior на одном Container: у Galaxy (яркие
            // звёзды у самого края) общая антиалиased-граница штриха
            // бордера и клипа давала заметный шов, на гладких градиентах
            // незаметный. Сплошная залитая "рамка"-подложка снаружи +
            // отдельный ClipRRect чуть меньшего радиуса внутри — общей
            // границы больше нет ни у одного фона.
            //
            // ColoredBox(background) ВНУТРИ клипа обязателен: без своей
            // непрозрачной подложки полупрозрачные пиксели шейдера
            // просвечивали ЦВЕТ САМОЙ РАМКИ (белый primary у выбранной
            // карточки) вместо тёмного фона приложения — выглядело как
            // будто выбранный превью "засвечен". Теперь подложка внутри
            // клипа не зависит от того, что снаружи.
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 96,
              height: 96,
              padding: EdgeInsets.all(selected ? 2 : 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected ? PortColors.primary : PortColors.border,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(color: PortColors.background, child: _preview),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _label,
              style: PortText.small.copyWith(
                color: selected ? PortColors.foreground : PortColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Шаг "Язык" — тот же `PortTabsList`, что и табы секций в
/// settings_page.dart (мобильная раскладка) — уже выверенный, знакомый по
/// виду компонент вместо отдельно придуманных карточек-кнопок.
class LanguageStep extends ConsumerWidget {
  const LanguageStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(S.onboardingLanguageTitle, style: PortText.h4, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Center(
          child: PortTabsList<AppLanguage>(
            value: settings.language,
            items: [
              PortTabItem(value: AppLanguage.system, child: Text(S.languageSystem)),
              const PortTabItem(value: AppLanguage.ru, child: Text('Русский')),
              const PortTabItem(value: AppLanguage.en, child: Text('English')),
            ],
            onChanged: (value) => notifier.update((s) => s.copyWith(language: value)),
          ),
        ),
      ],
    );
  }
}

/// Шаг "Автозапуск" — только Windows, `OnboardingFlow` не включает этот шаг
/// в последовательность на Android вовсе (см. её doc-комментарий). Тот же
/// полный выбор, что и в `settings_page.dart`'s секции "Система" (трек 24)
/// — не упрощаем до одного тумблера, раз "с правами администратора"/
/// "показывать окно" настоящие независимые решения пользователя, а не
/// деталь для настроек постфактум.
class AutostartStep extends ConsumerStatefulWidget {
  const AutostartStep({super.key});

  @override
  ConsumerState<AutostartStep> createState() => _AutostartStepState();
}

class _AutostartStepState extends ConsumerState<AutostartStep> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(S.onboardingAutostartTitle, style: PortText.h4, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          S.onboardingAutostartCaption,
          style: PortText.muted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _SettingRow(
          label: S.autoStartPrivilegeLabel,
          child: PortSelect<AppAutoStartPrivilege>(
            initialValue: settings.autoStartPrivilege,
            onChanged: (value) {
              if (value == null) return;
              _applyAutoStart(privilege: value, showWindow: settings.autoStartShowWindow);
            },
            options: [
              PortSelectOption(
                value: AppAutoStartPrivilege.none,
                child: Text(S.autoStartPrivilegeNone),
              ),
              PortSelectOption(
                value: AppAutoStartPrivilege.standard,
                child: Text(S.autoStartPrivilegeStandard),
              ),
              PortSelectOption(
                value: AppAutoStartPrivilege.elevated,
                child: Text(S.autoStartPrivilegeElevated),
              ),
            ],
            selectedOptionBuilder: (context, value) => Text(switch (value) {
              AppAutoStartPrivilege.none => S.autoStartPrivilegeNone,
              AppAutoStartPrivilege.standard => S.autoStartPrivilegeStandard,
              AppAutoStartPrivilege.elevated => S.autoStartPrivilegeElevated,
            }),
          ),
        ),
        if (settings.autoStartPrivilege != AppAutoStartPrivilege.none) ...[
          const SizedBox(height: 12),
          PortSwitch(
            value: settings.autoStartShowWindow,
            label: Text(S.autoStartShowWindowLabel),
            onChanged: (value) => _applyAutoStart(
              privilege: settings.autoStartPrivilege,
              showWindow: value,
            ),
          ),
        ],
      ],
    );
  }

  void _applyAutoStart({
    required AppAutoStartPrivilege privilege,
    required bool showWindow,
  }) {
    setAutoStartOnBoot(privilege: privilege, showWindow: showWindow);
    ref
        .read(appSettingsProvider.notifier)
        .update((s) => s.copyWith(autoStartPrivilege: privilege, autoStartShowWindow: showWindow));
    if (privilege == AppAutoStartPrivilege.elevated) {
      _confirmElevatedAutoStart();
    }
  }

  Future<void> _confirmElevatedAutoStart() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final registered = await isElevatedAutoStartActuallyRegistered();
    if (!mounted) return;
    PortToaster.of(context).show(
      PortToast(
        title: Text(registered ? S.elevatedAutoStartConfirmed : S.elevatedAutoStartDeclined),
      ),
    );
  }
}

/// Тот же паттерн, что `_SettingRow` в `settings_page.dart` — ярлык слева,
/// контрол справа на одной линии; на узких окнах (см. ROADMAP.md, трек 16)
/// не помещаются рядом, тогда контрол уходит под ярлык.
class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _SettingRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
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

/// Шаг гайда — один интерактивный экран вместо отдельных статичных слайдов
/// "про папки" и "про drag&drop": фейковое дерево (`buildOnboardingDemoNodes`)
/// уже содержит группу (тап разворачивает — демонстрирует группировку) и
/// несколько строк, которые можно перетащить (демонстрирует сортировку) —
/// один и тот же `ProxyTreeList`, что и в реальном списке серверов
/// (`server_list_panel.dart`), просто с локальным fake-состоянием вместо
/// `coreConfigProvider`.
class GuideDemoStep extends StatefulWidget {
  const GuideDemoStep({super.key});

  @override
  State<GuideDemoStep> createState() => _GuideDemoStepState();
}

class _GuideDemoStepState extends State<GuideDemoStep> {
  late List<ProxyNode> _nodes = buildOnboardingDemoNodes();
  String? _selectedLeafId;

  // Не production-алгоритм (см. `core_config_provider.dart`'s `moveNode` для
  // настоящей версии с несколькими подписками) — тут ровно один
  // `ServerGroup` и плоский top-level список, этого достаточно для демо на
  // фиксированном фейковом дереве.
  void _onReorder(String draggedId, String targetParentGroupId, int targetIndex) {
    setState(() {
      ProxyNode? dragged;
      final topLevel = <ProxyNode>[];
      for (final node in _nodes) {
        if (node.id == draggedId) {
          dragged = node;
          continue;
        }
        if (node is ServerGroup) {
          final stillThere = node.children.where((c) => c.id != draggedId).toList();
          if (stillThere.length != node.children.length) {
            dragged = node.children.firstWhere((c) => c.id == draggedId);
          }
          topLevel.add(
            ServerGroup(id: node.id, name: node.name, icon: node.icon, children: stillThere),
          );
        } else {
          topLevel.add(node);
        }
      }
      final removed = dragged;
      if (removed == null) return;

      if (targetParentGroupId == standaloneParentId) {
        topLevel.insert(targetIndex.clamp(0, topLevel.length), removed);
        _nodes = topLevel;
        return;
      }

      // Если перетаскиваемый узел — сама группа-цель (или другая причина,
      // по которой цели уже нет среди topLevel после извлечения — сейчас
      // такое возможно только для self-дропа, ancestorGroupIds в
      // ProxyTreeList должен вообще не пускать сюда такой дроп, но это
      // отдельная, локальная demo-реализация reorder, а не
      // moveNodeInTree — держим свою защиту тоже, а не полагаемся только
      // на UI-guard): без этой проверки узел просто пропадал — извлекли
      // его из дерева, а вставить оказалось некуда.
      if (!topLevel.any((n) => n is ServerGroup && n.id == targetParentGroupId)) {
        return;
      }

      _nodes = [
        for (final node in topLevel)
          if (node is ServerGroup && node.id == targetParentGroupId)
            ServerGroup(
              id: node.id,
              name: node.name,
              icon: node.icon,
              children: [...node.children]
                ..insert(targetIndex.clamp(0, node.children.length), removed),
            )
          else
            node,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(S.onboardingGuideTitle, style: PortText.h4, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(S.onboardingGuideCaption, style: PortText.muted, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: PortColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ProxyTreeList(
            nodes: _nodes,
            selectedLeafId: _selectedLeafId,
            onSelectLeaf: (id) => setState(() => _selectedLeafId = id),
            onSelectVariant: (leafId, variantId) {},
            onReorder: _onReorder,
          ),
        ),
      ],
    );
  }
}
