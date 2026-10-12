import 'package:ovrld_core/ovrld_core.dart';
import 'package:test/test.dart';

void main() {
  group('units', () {
    test('kg round-trips through lb exactly enough', () {
      for (final kg in [0.0, 2.5, 100.0, 102.5, 227.5]) {
        expect(displayToKg(kgToDisplay(kg, WeightUnit.lb), WeightUnit.lb),
            closeTo(kg, 1e-9));
      }
    });
    test('formatNumber trims', () {
      expect(formatNumber(100), '100');
      expect(formatNumber(102.5), '102.5');
      expect(formatNumber(101.25), '101.25');
      expect(formatNumber(-0.0001), '0');
    });
    test('formatWeight rounds to loadable plates', () {
      expect(formatWeight(100, WeightUnit.kg), '100');
      expect(formatWeight(100, WeightUnit.lb), '220.5');
    });
    test('lb step is plate-shaped', () {
      expect(displayStep(2.5, WeightUnit.lb), 5);
      expect(displayStep(1.25, WeightUnit.lb), 2.5);
      expect(displayStep(5, WeightUnit.lb), 10);
      expect(displayStep(2.5, WeightUnit.kg), 2.5);
    });
    test('pace and clock', () {
      final p = paceSeconds(27 * 60 + 41, 5200, DistanceUnit.km)!;
      expect(formatClock(p), '5:19');
      expect(formatClock(4062), '1:07:42');
      expect(paceSeconds(100, 0, DistanceUnit.km), isNull);
      expect(speed(3600, 30000, DistanceUnit.km), 30);
      expect(pacePer100m(120, 100), 120);
    });
    test('thousands', () {
      expect(formatThousands(8940), '8 940');
      expect(formatThousands(940), '940');
      expect(formatThousands(1234567), '1 234 567');
    });
    test('feet and inches', () {
      expect(cmToFeetInches(180), (5, 11));
      expect(feetInchesToCm(5, 11), closeTo(180.34, 0.01));
    });
  });

  group('progression', () {
    test('e1rm Epley with cap', () {
      expect(e1rm(100, 1), 100);
      expect(e1rm(100, 8), closeTo(126.67, 0.01));
      expect(e1rm(100, 13), isNull);
      expect(e1rm(0, 5), isNull);
    });
    test('all sets at top of range earns the increment', () {
      final t = nextTarget(
        last: const [SetResult(100, 8), SetResult(100, 8), SetResult(100, 8)],
        repMin: 6, repMax: 8, incrementKg: 2.5, plannedSets: 3,
      )!;
      expect(t.increase, isTrue);
      expect(t.kg, 102.5);
      expect(t.reps, 6);
    });
    test('one short set keeps the weight and asks for one more rep', () {
      final t = nextTarget(
        last: const [SetResult(100, 8), SetResult(100, 8), SetResult(100, 7), SetResult(100, 7)],
        repMin: 6, repMax: 8, incrementKg: 2.5, plannedSets: 4,
      )!;
      expect(t.increase, isFalse);
      expect(t.kg, 100);
      expect(t.reps, 8);
    });
    test('a short day does not earn the increment', () {
      final t = nextTarget(
        last: const [SetResult(100, 8), SetResult(100, 8)],
        repMin: 6, repMax: 8, incrementKg: 2.5, plannedSets: 4,
      )!;
      expect(t.increase, isFalse);
    });
    test('warm-ups and lighter back-off sets are ignored', () {
      final t = nextTarget(
        last: const [
          SetResult(60, 10, warmup: true),
          SetResult(100, 8), SetResult(100, 8),
          SetResult(80, 12),
        ],
        repMin: 6, repMax: 8, incrementKg: 2.5, plannedSets: 2,
      )!;
      expect(t.increase, isTrue);
      expect(t.kg, 102.5);
    });
    test('no history, no target', () {
      expect(nextTarget(last: const [], repMin: 6, repMax: 8, incrementKg: 2.5), isNull);
    });
    test('volume skips warm-ups', () {
      expect(volume(const [SetResult(50, 10, warmup: true), SetResult(100, 5)]), 500);
    });
  });

  group('records', () {
    test('first ever set is a baseline, not a PR', () {
      expect(Bests().wouldBeat(const SetResult(100, 5)), isEmpty);
    });
    test('beating heaviest, e1rm and reps', () {
      final b = Bests.from(const [SetResult(100, 8), SetResult(90, 10)]);
      expect(b.wouldBeat(const SetResult(102.5, 6)), {PrKind.heaviest});
      expect(b.wouldBeat(const SetResult(100, 9)), {PrKind.e1rm, PrKind.reps});
      expect(b.wouldBeat(const SetResult(90, 11)), {PrKind.reps});
      expect(b.wouldBeat(const SetResult(100, 8)), isEmpty);
      expect(b.wouldBeat(const SetResult(110, 1, warmup: true)), isEmpty);
    });
    test('bodyweight reps records at weight 0', () {
      final b = Bests.from(const [SetResult(0, 8)]);
      expect(b.wouldBeat(const SetResult(0, 9)), {PrKind.reps});
      expect(b.wouldBeat(const SetResult(0, 8)), isEmpty);
    });
  });

  group('calendar', () {
    test('weeks start Monday', () {
      expect(startOfWeek(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
      expect(startOfWeek(DateTime(2026, 10, 18, 23, 59)), DateTime(2026, 10, 12));
      expect(startOfWeek(DateTime(2026, 10, 19)), DateTime(2026, 10, 19));
    });
    test('ISO week numbers', () {
      expect(isoWeek(DateTime(2026, 10, 12)), 42);
      expect(isoWeek(DateTime(2021, 1, 3)), 53);
      expect(isoWeek(DateTime(2021, 1, 4)), 1);
      expect(isoWeek(DateTime(2024, 12, 30)), 1);
    });
    test('days between across DST', () {
      expect(daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
      expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
    });
    test('short date', () {
      expect(shortDate(DateTime(2026, 10, 12)), 'MON 12 OCT');
    });
    test('week streak', () {
      final done = {DateTime(2026, 10, 5), DateTime(2026, 9, 28)};
      expect(
        weekStreak(today: DateTime(2026, 10, 13), weekComplete: done.contains),
        2,
      );
    });
  });
}
