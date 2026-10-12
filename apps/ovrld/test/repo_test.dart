import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ovrld/data/models.dart';
import 'package:ovrld/data/repo.dart';
import 'package:ovrld/data/schema.dart';
import 'package:ovrld/data/seed.dart';
import 'package:ovrld/data/analytics.dart';
import 'package:ovrld/screens/today_screen.dart' show supersetLabels;
import 'package:ovrld_core/ovrld_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
          await db.execute(s.replaceFirst(',\n    tour_seen INTEGER NOT NULL DEFAULT 0', ''));
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

  test('superset labels', () {
    expect(supersetLabels([null, 1, 1, null, 2, 2, 2]), [null, 'A1', 'A2', null, 'B1', 'B2', 'B3']);
    expect(supersetLabels([1]), [null]);
  });
}
