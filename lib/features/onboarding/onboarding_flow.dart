import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core_abstraction/app_settings_provider.dart';
import '../../l10n/strings.dart';
import '../../widgets/port_ui/port_ui.dart';
import 'onboarding_steps.dart';

/// Первый запуск — необязательный визард вместо `ConnectionScreen` (см.
/// `main.dart`, ветка по `settings.onboardingCompleted`). Шаг 0 —
/// приветствие с выбором "Настроить"/"Пропустить" (`WelcomeStep`, свои
/// большие кнопки). Дальше идут шаги-настройки (фон/язык/автозапуск — не
/// показываем последний на Android, там нет автозапуска, см.
/// `_visibleSettingsSections` в `settings_page.dart`) и один интерактивный
/// шаг-гайд (группировка + drag&drop на фейковых данных). На каждом шаге,
/// кроме приветствия (там это и так один из двух главных вариантов) — своя
/// маленькая кнопка "Пропустить" в углу, чтобы выйти из визарда одним тапом
/// в любой момент, оставив уже применённые на пройденных шагах настройки
/// как есть (каждый шаг применяет их сразу через `appSettingsProvider`, как
/// и весь остальной Settings — отдельного "Save" тут тоже нет).
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  // 0 = WelcomeStep, 1.._configSteps.length = _configSteps[index - 1].
  int _stepIndex = 0;

  // Не `static const` — `Platform.isAndroid` не константа времени
  // компиляции, а Windows-only autostart-шаг должен платформенно
  // исключаться из последовательности (Android не показывает эту секцию и
  // в обычном Settings, `_visibleSettingsSections`, нет
  // registry-автозапуска).
  late final _configSteps = [
    const BackgroundStep(),
    const LanguageStep(),
    if (!Platform.isAndroid) const AutostartStep(),
    const GuideDemoStep(),
  ];

  void _complete() {
    ref.read(appSettingsProvider.notifier).update(
      (s) => s.copyWith(onboardingCompleted: true),
    );
  }

  void _customize() => setState(() => _stepIndex = 1);

  void _next() {
    if (_stepIndex >= _configSteps.length) {
      _complete();
    } else {
      setState(() => _stepIndex++);
    }
  }

  void _back() => setState(() => _stepIndex--);

  @override
  Widget build(BuildContext context) {
    final isLastStep = _stepIndex == _configSteps.length;

    return ColoredBox(
      color: PortColors.background,
      child: SafeArea(
        child: PopScope(
          canPop: _stepIndex == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _back();
          },
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: KeyedSubtree(
                            key: ValueKey(_stepIndex),
                            child: _stepIndex == 0
                                ? WelcomeStep(onCustomize: _customize, onSkip: _complete)
                                : _configSteps[_stepIndex - 1],
                          ),
                        ),
                        if (_stepIndex > 0) ...[
                          const SizedBox(height: 24),
                          _StepDots(total: _configSteps.length, current: _stepIndex - 1),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (_stepIndex > 1)
                                PortButton.outline(onPressed: _back, child: Text(S.onboardingBack))
                              else
                                const SizedBox.shrink(),
                              const Spacer(),
                              PortButton(
                                onPressed: _next,
                                child: Text(isLastStep ? S.onboardingDone : S.onboardingNext),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (_stepIndex > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: PortButton.ghost(onPressed: _complete, child: Text(S.onboardingSkip)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int total;
  final int current;
  const _StepDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: i == current ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == current ? PortColors.primary : PortColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }
}
