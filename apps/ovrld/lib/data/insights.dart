import 'package:ovrld_core/ovrld_core.dart';

import '../state/app_state.dart';
import 'models.dart';
import 'repo.dart';
import 'seed.dart';

/// One lift that has stopped moving, with what the stall card draws.
class StallInfo {
  StallInfo({required this.exercise, required this.stall, required this.history, required this.lastTopKg});
  final Exercise exercise;
  final Stall stall;

  /// Best e1RM per session, oldest first, for the sparkline.
  final List<(DateTime, double)> history;

  /// Heaviest working set of the last session: what a deload is 90% of.
  final double lastTopKg;
}

/// Everything the BODY view and the stall badges read, from one pass over
/// the logged sets.
class Insights {
  Insights({
    required this.windowDays,
    required this.sets,
    required this.lastTrained,
    required this.lifts,
    required this.stalls,
  });

  final int windowDays;

  /// Working sets per muscle inside the window, secondary muscles weighted.
  final Map<String, double> sets;

  /// Last day each muscle got a working set, primary or secondary, ever.
  final Map<String, DateTime> lastTrained;

  /// Exercise names per muscle inside the window, most sets first.
  final Map<String, List<String>> lifts;

  /// Stalls the lifter should see now: alerts on, not snoozed. By exercise.
  final Map<int, StallInfo> stalls;

  /// The muscles the map draws.
  static List<String> get mapped => muscles.where((m) => m != 'Full body').toList();

  double perWeek(String m) => (sets[m] ?? 0) / (windowDays / 7);

  /// Not trained at all in the window, then under 5 sets a week, worst first.
  List<String> get neglected =>
      mapped.where((m) => perWeek(m) < 5).toList()..sort((a, b) => perWeek(a).compareTo(perWeek(b)));

  static Future<Insights> load(AppState app) async =>
      compute(app.profile, app.exercises, await app.repo.loggedSets(), DateTime.now());

  static Insights compute(Profile p, Map<int, Exercise> exercises, List<LoggedSet> sets, DateTime now) {
    final today = dateOnly(now);
    final from = addDays(today, -p.bodyWindowDays + 1);
    final share = p.halfSecondary ? .5 : 0.0;

    final inWindow = <(String, List<String>)>[];
    final lastTrained = <String, DateTime>{};
    final liftSets = <String, Map<String, double>>{};
    final bySession = <int, Map<int, List<LoggedSet>>>{};

    for (final s in sets) {
      if (s.set.warmup) continue;
      final e = exercises[s.exerciseId];
      if (e == null) continue;
      final day = dateOnly(s.sessionStart);
      for (final m in [e.muscle, ...e.secondary]) {
        final prev = lastTrained[m];
        if (prev == null || day.isAfter(prev)) lastTrained[m] = day;
      }
      if (!day.isBefore(from)) {
        inWindow.add((e.muscle, e.secondary));
        for (final m in [e.muscle, if (share > 0) ...e.secondary]) {
          final names = liftSets.putIfAbsent(m, () => {});
          names[e.name] = (names[e.name] ?? 0) + (m == e.muscle ? 1 : share);
        }
      }
      if (e.usesWeight) {
        bySession.putIfAbsent(e.id, () => {}).putIfAbsent(s.sessionId, () => []).add(s);
      }
    }

    final stalls = <int, StallInfo>{};
    if (p.stallAlerts) {
      for (final MapEntry(key: id, value: sessions) in bySession.entries) {
        final e = exercises[id]!;
        final snooze = e.stallSnoozeUntil;
        if (snooze != null && now.isBefore(snooze)) continue;
        final history = <(DateTime, double)>[];
        for (final list in sessions.values) {
          final best = list
              .map((s) => e1rm(s.set.kg, s.set.reps))
              .whereType<double>()
              .fold<double>(0, (a, b) => a > b ? a : b);
          if (best > 0) history.add((list.first.sessionStart, best));
        }
        history.sort((a, b) => a.$1.compareTo(b.$1));
        final stall = findStall(history, today: now, weeks: p.stallWeeks, resetAt: e.stallResetAt);
        if (stall == null) continue;
        final last = sessions.values.reduce((a, b) => a.first.sessionStart.isAfter(b.first.sessionStart) ? a : b);
        stalls[id] = StallInfo(
          exercise: e,
          stall: stall,
          history: history,
          lastTopKg: last.map((s) => s.set.kg).reduce((a, b) => a > b ? a : b),
        );
      }
    }

    return Insights(
      windowDays: p.bodyWindowDays,
      sets: muscleLoad(inWindow, secondaryShare: share),
      lastTrained: lastTrained,
      lifts: {
        for (final MapEntry(key: m, value: names) in liftSets.entries)
          m: (names.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((x) => x.key).toList(),
      },
      stalls: stalls,
    );
  }
}
