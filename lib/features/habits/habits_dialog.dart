import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/strings.dart';
import '../../widgets/port_ui/port_ui.dart';
import 'habit.dart';
import 'habit_store.dart';

Future<void> openHabits(BuildContext context) => showPortDialog<void>(
  context: context,
  builder: (_) => const HabitsDialog(),
);

class HabitsDialog extends StatefulWidget {
  const HabitsDialog({super.key});

  @override
  State<HabitsDialog> createState() => _HabitsDialogState();
}

class _HabitsDialogState extends State<HabitsDialog>
    with WidgetsBindingObserver {
  final _store = HabitStore();
  final _input = TextEditingController();
  List<Habit> _habits = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  Future<void> _load() async {
    try {
      final habits = await _store.load();
      if (mounted) {
        setState(() {
          _habits = habits;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = S.habitsLoadError;
        });
      }
    }
  }

  Future<void> _save(List<Habit> habits, {bool added = false}) async {
    if (_saving || _loading) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _store.save(habits);
      if (!mounted) return;
      setState(() {
        _habits = habits;
      });
      if (added) _input.clear();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = S.habitsSaveError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _add() {
    final name = _input.text.trim();
    if (name.isEmpty || name.length > 80) return;
    _save([..._habits, Habit(id: const Uuid().v4(), name: name)], added: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completed = _habits
        .where((h) => h.days.contains(habitDay(today)))
        .length;
    final enabled = !_loading && !_saving && _error != S.habitsLoadError;
    return PopScope(
      canPop: !_saving,
      child: PortDialog(
        title: Text(S.habitsTitle),
        description: Text(S.habitsSubtitle),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: PortText.muted.copyWith(color: PortColors.destructive),
              ),
              if (_error == S.habitsLoadError)
                PortButton.secondary(
                  onPressed: _load,
                  child: Text(S.habitsRetry),
                ),
              const SizedBox(height: 12),
            ],
            if (_loading)
              Text(S.habitsLoading, style: PortText.muted)
            else ...[
              Text(
                S.habitsProgress(completed, _habits.length),
                style: PortText.large,
              ),
              const SizedBox(height: 16),
              if (_habits.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(S.habitsEmpty, style: PortText.muted),
                ),
              for (final habit in _habits) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PortColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(habit.name, style: PortText.small),
                          ),
                          Semantics(
                            label: S.habitsDelete,
                            child: PortIconButton.ghost(
                              icon: const Icon(LucideIcons.trash2, size: 16),
                              onPressed: !enabled
                                  ? null
                                  : () async {
                                      final confirmed =
                                          await showPortDialog<bool>(
                                            context: context,
                                            builder: (context) =>
                                                PortDialog.alert(
                                                  title: Text(S.habitsDelete),
                                                  description: Text(habit.name),
                                                  actions: [
                                                    PortButton.ghost(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            context,
                                                          ).pop(false),
                                                      child: Text(S.cancel),
                                                    ),
                                                    PortButton.destructive(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            context,
                                                          ).pop(true),
                                                      child: Text(
                                                        S.habitsDelete,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          );
                                      if (confirmed == true && mounted) {
                                        _save(
                                          _habits
                                              .where((h) => h.id != habit.id)
                                              .toList(),
                                        );
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      Text(
                        S.habitsStreak(habit.streak(today)),
                        style: PortText.muted,
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 6; i >= 0; i--) ...[
                              if (i < 6) const SizedBox(width: 2),
                              SizedBox(
                                width: 44,
                                child: _day(
                                  habit,
                                  DateTime(
                                    today.year,
                                    today.month,
                                    today.day - i,
                                  ),
                                  enabled,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
            PortInput(
              controller: _input,
              enabled: enabled,
              placeholder: S.habitsPlaceholder,
              onSubmitted: (_) => _add(),
            ),
            const SizedBox(height: 8),
            PortButton(
              onPressed: enabled ? _add : null,
              leading: const Icon(LucideIcons.plus),
              child: Text(S.habitsAdd),
            ),
          ],
        ),
      ),
    );
  }

  Widget _day(Habit habit, DateTime date, bool enabled) {
    final done = habit.days.contains(habitDay(date));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${date.day}.${date.month}',
          style: PortText.muted.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 4),
        Semantics(
          label: '${habit.name}, ${habitDay(date)}',
          toggled: done,
          child: PortIconButton.secondary(
            size: 28,
            icon: Icon(
              done ? LucideIcons.check : LucideIcons.minus,
              size: 16,
              color: done
                  ? const Color(0xFF22C55E)
                  : PortColors.mutedForeground,
            ),
            onPressed: enabled
                ? () => _save([
                    for (final h in _habits)
                      h.id == habit.id ? h.toggle(date) : h,
                  ])
                : null,
          ),
        ),
      ],
    );
  }
}
