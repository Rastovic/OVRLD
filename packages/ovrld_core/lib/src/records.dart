/// Personal records for one exercise. Built from history once, then fed each
/// new set to ask "did that beat anything?".
library;

import 'progression.dart';

enum PrKind { e1rm, heaviest, reps }

class Bests {
  Bests();

  factory Bests.from(Iterable<SetResult> history) {
    final b = Bests();
    for (final s in history) {
      b.add(s);
    }
    return b;
  }

  double bestE1rm = 0;
  double heaviest = 0;
  int count = 0;

  /// Most reps ever done at each exact weight. Weight 0 is a real key: it is
  /// how bodyweight pull-ups and plain push-ups keep a reps record.
  final Map<double, int> repsAt = {};

  bool get isEmpty => count == 0;

  /// What [s] would beat. An exercise with no history yields nothing: the
  /// first set ever logged is a baseline, not a record.
  Set<PrKind> wouldBeat(SetResult s) {
    if (s.warmup || s.reps <= 0 || s.kg < 0 || isEmpty) return {};
    final out = <PrKind>{};
    final e = e1rm(s.kg, s.reps);
    if (e != null && e > bestE1rm + 1e-9) out.add(PrKind.e1rm);
    if (s.kg > 0 && s.kg > heaviest + 1e-9) out.add(PrKind.heaviest);
    final prev = repsAt[s.kg];
    if (prev != null && s.reps > prev) out.add(PrKind.reps);
    return out;
  }

  void add(SetResult s) {
    if (s.warmup || s.reps <= 0 || s.kg < 0) return;
    count++;
    final e = e1rm(s.kg, s.reps);
    if (e != null && e > bestE1rm) bestE1rm = e;
    if (s.kg > heaviest) heaviest = s.kg;
    final prev = repsAt[s.kg] ?? 0;
    if (s.reps > prev) repsAt[s.kg] = s.reps;
  }
}
