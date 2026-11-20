/// Local calendar dates deliberately avoid elapsed-time arithmetic across DST.
String habitDay(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class Habit {
  final String id;
  final String name;
  final Set<String> days;

  Habit({required this.id, required this.name, Set<String>? days})
    : days = Set.unmodifiable(days ?? {});

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
    id: json['id'] as String,
    name: json['name'] as String,
    days: (json['days'] as List).cast<String>().toSet(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'days': days.toList()..sort(),
  };

  Habit toggle(DateTime date) {
    final updated = {...days};
    final day = habitDay(date);
    if (!updated.remove(day)) updated.add(day);
    return Habit(id: id, name: name, days: updated);
  }

  int streak(DateTime today) {
    var date = DateTime(today.year, today.month, today.day);
    if (!days.contains(habitDay(date))) {
      date = DateTime(date.year, date.month, date.day - 1);
    }
    var count = 0;
    while (days.contains(habitDay(date))) {
      count++;
      date = DateTime(date.year, date.month, date.day - 1);
    }
    return count;
  }
}
