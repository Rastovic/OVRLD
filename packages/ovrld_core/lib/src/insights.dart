/// What the body map and the stall alerts are made of: sets per muscle over a
/// window, and lifts whose estimated 1RM has stopped going up.
library;

/// Working sets per muscle. The primary muscle gets a whole set, each
/// secondary muscle [secondaryShare] of one (½ by default, 0 to ignore them).
Map<String, double> muscleLoad(
  Iterable<(String primary, List<String> secondary)> sets, {
  double secondaryShare = .5,
}) {
  final out = <String, double>{};
  for (final (p, sec) in sets) {
    out[p] = (out[p] ?? 0) + 1;
    if (secondaryShare <= 0) continue;
    for (final m in sec) {
      if (m == p) continue;
      out[m] = (out[m] ?? 0) + secondaryShare;
    }
  }
  return out;
}

/// A lift whose best estimated 1RM has not gone up for a while.
class Stall {
  const Stall({required this.since, required this.best, required this.weeks});

  /// The session that set the best that has not been beaten since.
  final DateTime since;
  final double best;

  /// Whole weeks from [since] to today.
  final int weeks;
}

/// [sessions] is one (date, best e1RM that session) per session, any order.
///
/// Stalled means: nothing in the last [weeks] weeks beat the best from before
/// them, and the lift was trained at least twice in those weeks. A lift you
/// stopped doing is not a stall, and neither is one you just started.
/// [resetAt] is when the lifter last acted on a stall (deload, new rep range):
/// the clock starts again from there.
Stall? findStall(
  List<(DateTime, double)> sessions, {
  required DateTime today,
  required int weeks,
  DateTime? resetAt,
}) {
  if (sessions.isEmpty || weeks <= 0) return null;
  final cut = today.subtract(Duration(days: 7 * weeks));
  if (resetAt != null && resetAt.isAfter(cut)) return null;
  final sorted = [...sessions]..sort((a, b) => a.$1.compareTo(b.$1));
  final before = sorted.where((s) => s.$1.isBefore(cut)).toList();
  final inside = sorted.where((s) => !s.$1.isBefore(cut)).toList();
  if (before.isEmpty || inside.length < 2) return null;
  var best = before.first;
  for (final s in before) {
    if (s.$2 > best.$2 + 1e-9) best = s;
  }
  final insideBest = inside.map((s) => s.$2).reduce((a, b) => a > b ? a : b);
  if (insideBest > best.$2 + 1e-9) return null;
  return Stall(since: best.$1, best: best.$2, weeks: today.difference(best.$1).inDays ~/ 7);
}
