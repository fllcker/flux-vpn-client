import 'package:flutter_test/flutter_test.dart';
import 'package:flux/features/habits/habit.dart';

void main() {
  test('toggle survives serialization and can be undone', () {
    final day = DateTime(2026, 11, 8);
    final habit = Habit(id: '1', name: 'Walk').toggle(day);
    final restored = Habit.fromJson(habit.toJson());
    expect(restored.days, {'2026-11-08'});
    expect(restored.toggle(day).days, isEmpty);
    expect(habit.days, {'2026-11-08'});
  });

  test('unfinished today retains yesterday streak across month boundary', () {
    final habit = Habit(
      id: '1',
      name: 'Walk',
      days: {'2026-10-30', '2026-10-31'},
    );
    expect(habit.streak(DateTime(2026, 11, 1)), 2);
    expect(habit.streak(DateTime(2026, 11, 2)), 0);
    expect(
      habit.toggle(DateTime(2026, 11, 1)).streak(DateTime(2026, 11, 1)),
      3,
    );
  });

  test('calendar dates and streak cross leap day', () {
    final habit = Habit(
      id: '1',
      name: 'Walk',
      days: {'2028-02-28', '2028-02-29', '2028-03-01'},
    );
    expect(habit.streak(DateTime(2028, 3, 1, 23)), 3);
    expect(habitDay(DateTime(2028, 2, 29, 23)), '2028-02-29');
  });
}
