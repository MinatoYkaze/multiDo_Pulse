/// Consecutive-day streak logic shared by Analytics and the milestone screen.
class StreakInfo {
  const StreakInfo(this.current, this.best);
  final int current, best;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// A day is "active" if it has any completed task or focus session.
/// The current streak survives until the end of the day after the last
/// active day (so it doesn't read 0 first thing in the morning).
StreakInfo computeStreaks(Iterable<DateTime> activeTimestamps) {
  final days = activeTimestamps.map(_day).toSet().toList()..sort();
  if (days.isEmpty) return const StreakInfo(0, 0);

  var best = 1, run = 1;
  for (var i = 1; i < days.length; i++) {
    run = days[i].difference(days[i - 1]).inDays == 1 ? run + 1 : 1;
    if (run > best) best = run;
  }

  final today = _day(DateTime.now());
  final last = days.last;
  var current = 0;
  if (today.difference(last).inDays <= 1) {
    current = 1;
    for (var i = days.length - 1; i > 0; i--) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        current++;
      } else {
        break;
      }
    }
  }
  return StreakInfo(current, best);
}
