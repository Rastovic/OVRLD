import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ovrld/data/models.dart';
import 'package:ovrld/data/repo.dart';
import 'package:ovrld/data/schema.dart';
import 'package:ovrld/data/seed.dart';
import 'package:ovrld/data/analytics.dart';
import 'package:ovrld/data/insights.dart';
import 'package:ovrld/screens/today_screen.dart' show supersetLabels;
import 'package:ovrld_core/ovrld_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A finished session [daysAgo] days back with [sets] working sets of one lift.
Future<void> logged(Repo r, int exerciseId, int daysAgo, double kg, int reps, {int sets = 3}) async {
  final sid = await r.startSession(name: 'Past');
  final item = await r.addItem(sid, exerciseId, repMin: 5, repMax: 8);
  for (var k = 0; k < sets; k++) {
    await r.addSet(item, idx: k, kg: kg, reps: reps);
  }
  final at = DateTime.now().subtract(Duration(days: daysAgo));
  await r.finishSession(sid, endedAt: at.add(const Duration(hours: 1)));
  final s = (await r.fullSession(sid)).session..startedAt = at;
  await r.updateSession(s);
}

/// Columns v3 added, to rebuild an older database from today's statements.
final v3Columns = RegExp(
    r',\n\s+(stall_weeks|body_window_days|half_secondary|stall_alerts|body_figure|secondary|stall_reset_at|stall_snooze_until|deload_kg) [^,\n]*');

Future<Repo> fresh() async {
  sqfliteFfiInit();
  return Repo.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
}

void main() {
  test('seed creates profile, splits and exercises', () async {
    final r = await fresh();
    expect((await r.profile()).onboarded, isFalse);
    expect((await r.splits()).length, seedSplits.length);
    expect((await r.exercises()).length, seedExercises.length);
    final names = seedExercises.map((e) => e.$1).toList();
    expect(names.toSet().length, names.length, reason: 'duplicate exercise names');
  });

  test('starter plan: 4 workouts, 7 days, supersets intact', () async {
    final r = await fresh();
    await r.createStarterPlan();
    final plan = (await r.activePlan())!;
    expect(plan.days.length, 7);
    expect(plan.trainingDays, 5);
    expect(plan.days[2].kind, DayKind.rest);
    expect(plan.days[5].kind, DayKind.cardio);
    final t = await r.templates();
    expect(t.length, 4);
    final legs = t.firstWhere((x) => x.name == 'Leg day');
    expect(supersetLabels(legs.items.map((i) => i.grp).toList()), [null, null, null, 'A1', 'A2']);
  });

  test('session is a snapshot: editing the workout later does not touch it', () async {
    final r = await fresh();
    await r.createStarterPlan();
    final legs = (await r.templates()).firstWhere((x) => x.name == 'Leg day');
    final sid = await r.startSession(t: legs);
    legs.items.removeLast();
    await r.saveTemplate(legs);
    final f = await r.fullSession(sid);
    expect(f.items.length, 5);
  });

  test('last time, progression and PRs across sessions', () async {
    final r = await fresh();
    await r.createStarterPlan();
    final legs = (await r.templates()).firstWhere((x) => x.name == 'Leg day');
    final squat = legs.items.first; // 4 × 6-8

    final s1 = await r.startSession(t: legs);
    final i1 = (await r.fullSession(s1)).items.first.id;
    await r.addSet(i1, idx: 0, kg: 60, reps: 10, warmup: true);
    for (var k = 1; k <= 4; k++) {
      await r.addSet(i1, idx: k, kg: 100, reps: 8);
    }
    await r.finishSession(s1, energy: 4, feel: 4);

    final last = (await r.lastTime(squat.exerciseId))!;
    expect(last.working.length, 4);
    final t = nextTarget(
      last: [for (final s in last.sets) s.result],
      repMin: squat.repMin,
      repMax: squat.repMax,
      incrementKg: 2.5,
      plannedSets: last.setsPlanned,
    )!;
    expect(t.increase, isTrue);
    expect(t.kg, 102.5);

    final s2 = await r.startSession(t: legs);
    final i2 = (await r.fullSession(s2)).items.first.id;
    await r.addSet(i2, idx: 0, kg: 102.5, reps: 6);
    await r.addSet(i2, idx: 1, kg: 102.5, reps: 6);
    await r.finishSession(s2);
    final prs = await prsInSession(r, await r.fullSession(s2));
    expect(prs.length, 1, reason: 'only the first set at a new heaviest weight is a record');
    expect(prs.values.single, contains(PrKind.heaviest));

    // The first session had no history: its sets are a baseline, not PRs.
    expect(await prsInSession(r, await r.fullSession(s1)), isEmpty);
  });

  test('open session is found and deleting it removes its sets', () async {
    final r = await fresh();
    final sid = await r.startSession(name: 'Quick');
    final ex = (await r.exercises()).first;
    final item = await r.addItem(sid, ex.id, repMin: 8, repMax: 12);
    await r.addSet(item, idx: 0, kg: 20, reps: 10);
    expect((await r.openSession())!.id, sid);
    await r.deleteSession(sid);
    expect(await r.openSession(), isNull);
    expect(await r.db.query('set_entry'), isEmpty);
  });

  test('body weight: one reading per day', () async {
    final r = await fresh();
    await r.addBodyWeight(DateTime(2026, 10, 12, 8), 70);
    await r.addBodyWeight(DateTime(2026, 10, 12, 20), 70.4);
    final bw = await r.bodyWeights();
    expect(bw.length, 1);
    expect(bw.single.kg, 70.4);
  });

  test('backup round trip is exact', () async {
    final a = await fresh();
    await a.createStarterPlan();
    final p = await a.profile()
      ..name = 'Jelena'
      ..onboarded = true;
    await a.saveProfile(p);
    final legs = (await a.templates()).first;
    final sid = await a.startSession(t: legs);
    final item = (await a.fullSession(sid)).items.first.id;
    await a.addSet(item, idx: 0, kg: 100, reps: 8);
    await a.finishSession(sid, energy: 5, note: 'felt great');
    await a.saveCardio(Cardio(activity: CardioActivity.run, startedAt: DateTime(2026, 10, 10), durationS: 1661, distanceM: 5200));
    await a.addBodyWeight(DateTime(2026, 10, 12), 64.5);

    final dump = jsonDecode(jsonEncode(await a.exportAll())) as Map<String, Object?>;
    final b = await fresh();
    await b.importAll(dump);
    final dump2 = jsonDecode(jsonEncode(await b.exportAll())) as Map<String, Object?>;
    expect(dump2['tables'], dump['tables']);
    expect((await b.profile()).name, 'Jelena');
  });

  test('restore refuses a file that is not an OVRLD backup', () async {
    final r = await fresh();
    expect(() => r.importAll({'app': 'other'}), throwsFormatException);
    expect(() => r.importAll({'app': 'ovrld', 'schema': 99, 'tables': {}}), throwsFormatException);
  });

  test('a v1 database upgrades to v2 and keeps everything', () async {
    sqfliteFfiInit();
    final path = '${Directory.systemTemp.createTempSync('ovrld').path}/v1.db';
    // Build exactly what v0.1.0 created: the v1 profile has no tour_seen.
    final v1 = await databaseFactoryFfiNoIsolate.openDatabase(path, options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        for (final s in createStatements) {
          await db.execute(s.replaceAll(v3Columns, '').replaceFirst(',\n    tour_seen INTEGER NOT NULL DEFAULT 0', ''));
        }
        await db.insert('profile', {'id': 1, 'name': 'Jelena', 'onboarded': 1});
        await db.insert('body_weight', {'date': '2026-10-12', 'kg': 64.0});
      },
    ));
    expect((await v1.rawQuery('PRAGMA table_info(profile)')).any((c) => c['name'] == 'tour_seen'), isFalse);
    await v1.close();

    final r = await Repo.open(path, factory: databaseFactoryFfiNoIsolate);
    final p = await r.profile();
    expect(p.name, 'Jelena');
    expect(p.onboarded, isTrue);
    expect(p.tourSeen, isFalse, reason: 'existing users see the walkthrough once');
    expect((await r.bodyWeights()).single.kg, 64.0);
    await r.db.close();
  });

  test('a v2 database upgrades to v3: muscles split, new lifts added, custom kept', () async {
    sqfliteFfiInit();
    final path = '${Directory.systemTemp.createTempSync('ovrld').path}/v2.db';
    final v2 = await databaseFactoryFfiNoIsolate.openDatabase(path, options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, _) async {
        for (final s in createStatements) {
          await db.execute(s.replaceAll(v3Columns, ''));
        }
        await db.insert('profile', {'id': 1, 'name': 'Jelena', 'onboarded': 1, 'tour_seen': 1});
        for (final (name, muscle, custom) in [
          ('Lateral raise', 'Shoulders', 0),
          ('Pull-up', 'Back', 0),
          ('Plank', 'Core', 0),
          ('My machine row', 'Back', 1),
        ]) {
          await db.insert('exercise', {'name': name, 'muscle': muscle, 'equipment': 'Other', 'kind': 'weightReps', 'custom': custom});
        }
      },
    ));
    expect((await v2.rawQuery('PRAGMA table_info(exercise)')).any((c) => c['name'] == 'secondary'), isFalse);
    await v2.close();

    final r = await Repo.open(path, factory: databaseFactoryFfiNoIsolate);
    final ex = {for (final e in await r.exercises()) e.name: e};
    expect(ex['Lateral raise']!.muscle, 'Side delts');
    expect(ex['Pull-up']!.muscle, 'Lats');
    expect(ex['Pull-up']!.secondary, ['Biceps', 'Upper back']);
    expect(ex['Plank']!.muscle, 'Abs');
    expect(ex['My machine row']!.muscle, 'Upper back', reason: 'custom lifts fall back by old group');
    expect(ex.containsKey('Hip adduction'), isTrue, reason: 'lifts new in v3 are added');
    expect(ex.values.every((e) => muscles.contains(e.muscle)), isTrue);
    final p = await r.profile();
    expect(p.name, 'Jelena');
    expect(p.stallWeeks, 3);
    expect(p.bodyWindowDays, 15);
    await r.db.close();
  });

  test('restoring a v2 backup maps the old muscles too', () async {
    final a = await fresh();
    final dump = jsonDecode(jsonEncode(await a.exportAll())) as Map<String, Object?>;
    dump['schema'] = 2;
    for (final row in ((dump['tables'] as Map)['exercise'] as List).cast<Map>()) {
      row.removeWhere((k, _) => ['secondary', 'stall_reset_at', 'stall_snooze_until', 'deload_kg'].contains(k));
      if (row['name'] == 'Face pull') row['muscle'] = 'Shoulders';
    }
    final b = await fresh();
    await b.importAll(dump);
    final face = (await b.exercises()).firstWhere((e) => e.name == 'Face pull');
    expect(face.muscle, 'Rear delts');
    expect(face.secondary, contains('Upper back'));
  });

  test('a deload lasts one finished session', () async {
    final r = await fresh();
    final bench = (await r.exercises()).firstWhere((e) => e.name == 'Bench press')..deloadKg = 72.5;
    await r.updateExercise(bench);
    expect((await r.exercises()).firstWhere((e) => e.id == bench.id).deloadKg, 72.5);
    await logged(r, bench.id, 0, 72.5, 8);
    expect((await r.exercises()).firstWhere((e) => e.id == bench.id).deloadKg, isNull);
  });

  test('insights: sets per muscle with helpers at half, and a stalled lift', () async {
    final r = await fresh();
    final ex = {for (final e in await r.exercises()) e.name: e};
    final bench = ex['Bench press']!, squat = ex['Back squat']!;
    await logged(r, bench.id, 45, 100, 5);
    await logged(r, bench.id, 30, 102.5, 5);
    await logged(r, bench.id, 10, 100, 5);
    await logged(r, bench.id, 3, 102.5, 4);
    await logged(r, squat.id, 40, 120, 5);
    await logged(r, squat.id, 9, 125, 5);
    await logged(r, squat.id, 2, 130, 5);
    final byId = {for (final e in await r.exercises()) e.id: e};
    final d = Insights.compute(Profile(), byId, await r.loggedSets(), DateTime.now());
    expect(d.sets['Chest'], 6, reason: 'two bench sessions in 15 days, 3 sets each');
    expect(d.sets['Triceps'], 3, reason: 'helpers count half');
    expect(d.sets['Quads'], 6);
    expect(d.stalls.keys, [bench.id], reason: 'squat keeps going up');
    expect(d.stalls[bench.id]!.stall.weeks, 4);
    expect(d.sets['Calves'], isNull);
    expect(d.neglected.indexOf('Calves'), lessThan(d.neglected.indexOf('Chest')), reason: 'untrained first, then low');

    final off = Insights.compute(Profile(halfSecondary: false, stallAlerts: false), byId, await r.loggedSets(), DateTime.now());
    expect(off.sets['Triceps'], isNull);
    expect(off.stalls, isEmpty);

    byId[bench.id]!.stallSnoozeUntil = DateTime.now().add(const Duration(days: 14));
    expect(Insights.compute(Profile(), byId, await r.loggedSets(), DateTime.now()).stalls, isEmpty);
  });

  test('every seeded lift uses known muscles', () {
    for (final (name, m, _, _, sec) in seedExercises) {
      expect(muscles, contains(m), reason: name);
      for (final x in sec) {
        expect(muscles, contains(x), reason: '$name: $x');
        expect(x, isNot(m), reason: name);
      }
    }
  });

  test('ready workouts: real lifts, about an hour, every muscle covered', () {
    final names = {for (final e in seedExercises) e.$1: e};
    final splits = {for (final s in seedSplits) s.$1};
    final hit = <String>{};
    for (final w in readyWorkouts) {
      expect(splits, contains(w.split), reason: w.name);
      final sets = w.items.fold<int>(0, (a, i) => a + i.$2);
      expect(workoutMinutes(sets), inInclusiveRange(55, 65), reason: '${w.name}: $sets sets');
      for (final i in w.items) {
        expect(names.keys, contains(i.$1), reason: '${w.name}: ${i.$1}');
        hit.add(names[i.$1]!.$2);
        hit.addAll(names[i.$1]!.$5);
      }
      expect(supersetLabels(w.items.map((i) => i.$5).toList()).whereType<String>().length.isEven, isTrue, reason: w.name);
    }
    expect(Insights.mapped.where((m) => !hit.contains(m)), isEmpty, reason: 'some muscle has no ready workout');
    for (final p in readyPlans) {
      expect(p.week.length, 7);
      for (final d in p.week.whereType<String>().where((d) => d != 'cardio')) {
        expect(readyWorkouts.map((w) => w.name), contains(d), reason: p.name);
      }
    }
  });

  test('a ready plan becomes the active week and reuses workouts already added', () async {
    final r = await fresh();
    await r.addReadyWorkout(readyWorkouts.firstWhere((w) => w.name == 'Upper body'));
    await r.addReadyPlan(readyPlans[1]);
    final plan = (await r.activePlan())!;
    expect(plan.name, 'Upper / Lower 4×');
    expect(plan.trainingDays, 5);
    final t = await r.templates();
    expect(t.map((x) => x.name).toSet(), {'Upper body', 'Legs · quads', 'Lower · glutes'});
    expect(plan.days[0].templateId, plan.days[3].templateId, reason: 'Monday and Thursday share one workout');
    final upper = t.firstWhere((x) => x.name == 'Upper body');
    expect(upper.items.length, 8);
    expect(upper.items.where((i) => i.grp != null).length, 4);
  });

  test('superset labels', () {
    expect(supersetLabels([null, 1, 1, null, 2, 2, 2]), [null, 'A1', 'A2', null, 'B1', 'B2', 'B3']);
    expect(supersetLabels([1]), [null]);
  });
}
