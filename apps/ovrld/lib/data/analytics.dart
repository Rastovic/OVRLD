import 'package:ovrld_core/ovrld_core.dart';

import 'models.dart';
import 'repo.dart';

/// Which sets of [f] were personal records at the time they were done:
/// compared with every earlier session, and with earlier sets of the same
/// session (the second set at a new best weight is not a second record).
Future<Map<int, Set<PrKind>>> prsInSession(Repo repo, FullSession f) async {
  final out = <int, Set<PrKind>>{};
  final byExercise = <int, List<SessionItem>>{};
  for (final i in f.items) {
    byExercise.putIfAbsent(i.exerciseId, () => []).add(i);
  }
  for (final entry in byExercise.entries) {
    final history = await repo.loggedSets(exerciseId: entry.key, excludeSession: f.session.id);
    final before = history.where((s) => s.sessionStart.isBefore(f.session.startedAt)).map((s) => s.set.result);
    final bests = Bests.from(before);
    final sets = entry.value.expand((i) => i.sets).toList()..sort((a, b) => a.doneAt.compareTo(b.doneAt));
    for (final s in sets) {
      final kinds = bests.wouldBeat(s.result);
      if (kinds.isNotEmpty) out[s.id] = kinds;
      bests.add(s.result);
    }
  }
  return out;
}

String prLabel(Set<PrKind> kinds) {
  if (kinds.contains(PrKind.heaviest)) return 'PR · HEAVIEST';
  if (kinds.contains(PrKind.e1rm)) return 'PR · 1RM';
  return 'PR · REPS';
}
