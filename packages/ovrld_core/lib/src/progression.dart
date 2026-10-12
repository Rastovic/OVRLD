/// Double progression: work inside a rep range at one weight until every
/// working set reaches the top of the range, then add the smallest increment
/// and start again from the bottom. The app suggests; it never insists.
library;

class SetResult {
  const SetResult(this.kg, this.reps, {this.warmup = false});
  final double kg;
  final int reps;
  final bool warmup;
}

/// Estimated one-rep max, Epley. Null above 12 reps, where the formula
/// overstates badly enough to invent PRs out of endurance sets.
double? e1rm(double kg, int reps) {
  if (reps <= 0 || kg <= 0) return null;
  if (reps == 1) return kg;
  if (reps > 12) return null;
  return kg * (1 + reps / 30);
}

class Target {
  const Target(this.kg, this.reps, {required this.increase});
  final double kg;
  final int reps;

  /// True when the target is a heavier weight than last time.
  final bool increase;
}

List<SetResult> workingSets(Iterable<SetResult> sets) =>
    sets.where((s) => !s.warmup && s.reps > 0).toList();

/// What to aim for next session, from what happened last session.
///
/// [plannedSets] guards against a short day: three of four sets at the top of
/// the range is not "all sets done", so it does not earn the increment.
Target? nextTarget({
  required List<SetResult> last,
  required int repMin,
  required int repMax,
  required double incrementKg,
  int? plannedSets,
}) {
  final work = workingSets(last);
  if (work.isEmpty) return null;
  final top = work.map((s) => s.kg).reduce((a, b) => a > b ? a : b);
  final atTop = work.where((s) => s.kg == top).toList();
  final enoughSets = plannedSets == null || atTop.length >= plannedSets;
  final allMaxed = atTop.every((s) => s.reps >= repMax);
  if (enoughSets && allMaxed && incrementKg > 0) {
    return Target(top + incrementKg, repMin, increase: true);
  }
  final weakest = atTop.map((s) => s.reps).reduce((a, b) => a < b ? a : b);
  final reps = (weakest + 1).clamp(repMin, repMax);
  return Target(top, reps, increase: false);
}

/// Sum of kg × reps over working sets.
double volume(Iterable<SetResult> sets) =>
    workingSets(sets).fold(0, (sum, s) => sum + s.kg * s.reps);
