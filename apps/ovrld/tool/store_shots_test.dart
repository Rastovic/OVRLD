// Renders the Play Store graphics from the real app, on a made-up demo
// account (8 weeks of training), with the app's own fonts.
//   flutter test tool/store_shots_test.dart
// Output: ~/Documents/apps/apps/15-ovrld/store/upload/
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ovrld/data/models.dart';
import 'package:ovrld/data/repo.dart';
import 'package:ovrld/main.dart';
import 'package:ovrld/screens/finish_screen.dart';
import 'package:ovrld/screens/session_screen.dart';
import 'package:ovrld/state/app_state.dart';
import 'package:ovrld/ui/tokens.dart';
import 'package:ovrld_core/ovrld_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final out = '${Platform.environment['HOME']}/Documents/apps/apps/15-ovrld/store/upload';
final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;

Future<void> loadFonts() async {
  Future<ByteData> f(String p) => File(p).readAsBytes().then((b) => b.buffer.asByteData());
  await (FontLoader('Archivo')..addFont(f('assets/fonts/Archivo.ttf'))).load();
  await (FontLoader('PlexMono')
        ..addFont(f('assets/fonts/IBMPlexMono-Regular.ttf'))
        ..addFont(f('assets/fonts/IBMPlexMono-Medium.ttf'))
        ..addFont(f('assets/fonts/IBMPlexMono-SemiBold.ttf')))
      .load();
  await (FontLoader('MaterialIcons')
        ..addFont(f('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')))
      .load();
}

/// Base working weight per exercise for the demo history.
const base = {
  'Back squat': 80.0, 'Romanian deadlift': 70.0, 'Leg press': 140.0, 'Walking lunge': 16.0,
  'Standing calf raise': 60.0, 'Bench press': 52.5, 'Overhead press': 35.0, 'Incline dumbbell press': 20.0,
  'Lateral raise': 8.0, 'Triceps pushdown': 25.0, 'Pull-up': 0.0, 'Barbell row': 55.0,
  'Seated cable row': 50.0, 'Face pull': 20.0, 'Dumbbell curl': 12.0, 'Incline bench press': 50.0,
  'Lat pulldown': 55.0, 'Dumbbell shoulder press': 18.0, 'Chest-supported row': 40.0,
  'Hammer curl': 14.0, 'Overhead triceps extension': 20.0,
};

Future<AppState> demo() async {
  sqfliteFfiInit();
  final r = await Repo.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
  await r.createStarterPlan();
  final today = dateOnly(DateTime.now());
  // Rotate the week so today is leg day: the store shows a training day.
  final plan = (await r.activePlan())!;
  final old = [...plan.days];
  final t0 = weekdayIndex(today);
  plan.days = [
    for (var i = 0; i < 7; i++)
      () {
        final o = old[(i - t0) % 7];
        return PlanDay(weekday: i, kind: o.kind, templateId: o.templateId, cardio: o.cardio, note: o.note);
      }(),
  ];
  plan.startedOn = addDays(today, -56);
  await r.savePlan(plan);
  final p = await r.profile()
    ..name = 'Alex'
    ..onboarded = true
    ..tourSeen = true
    ..heightCm = 172
    ..birthDate = DateTime(1996, 4, 18);
  await r.saveProfile(p);

  final names = {for (final e in await r.exercises()) e.id: e.name};
  final templates = {for (final t in await r.templates()) t.id: t};
  final count = <int, int>{}; // sessions per template so far
  const energies = [4, 3, 5, 4, 4, 2, 4, 5, 3, 4];
  var k = 0;
  for (var d = addDays(today, -56); d.isBefore(today); d = addDays(d, 1), k++) {
    if (k % 13 == 6) continue; // a missed day now and then
    final pd = plan.days[weekdayIndex(d)];
    if (pd.kind == DayKind.cardio) {
      final weeks = daysBetween(d, today) / 7;
      await r.saveCardio(Cardio(
        activity: CardioActivity.run,
        startedAt: d.add(const Duration(hours: 9)),
        durationS: (1600 + weeks * 18).round(),
        distanceM: 5000.0 + (k % 3) * 400,
        avgHr: 152 - (8 - weeks).round(),
        energy: energies[k % energies.length],
      ));
      continue;
    }
    if (pd.kind != DayKind.workout) continue;
    final t = templates[pd.templateId]!;
    final n = count[t.id!] = (count[t.id!] ?? -1) + 1;
    final sid = await r.startSession(t: t);
    final full = await r.fullSession(sid);
    for (final it in full.items) {
      final name = names[it.exerciseId]!;
      final kg = base[name]! + (name == 'Pull-up' ? 0 : (n ~/ 2) * (it.repMax >= 12 ? 1.0 : 2.5));
      for (var s = 0; s < it.setsPlanned; s++) {
        final reps = n.isOdd ? it.repMax : (s == 0 ? it.repMax : it.repMax - 1 - (s ~/ 2));
        await r.addSet(it.id, idx: s, kg: kg, reps: name == 'Pull-up' ? 6 + n ~/ 2 - s ~/ 2 : reps);
      }
    }
    final start = d.add(const Duration(hours: 18));
    final s = full.session
      ..startedAt = start
      ..endedAt = start.add(Duration(minutes: 52 + (k * 7) % 19))
      ..energy = energies[k % energies.length]
      ..feel = (energies[(k + 3) % energies.length]).clamp(2, 5);
    await r.updateSession(s);
  }
  for (var i = 0; i <= 56; i += 3) {
    await r.addBodyWeight(addDays(today, -56 + i), 65.4 - i * 0.025 + (i % 2) * 0.2);
  }
  final app = AppState(r);
  await app.load();
  return app;
}

Future<void> settle(WidgetTester t, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 120));
  }
}

Future<void> shoot(WidgetTester t, GlobalKey key, String name) async {
  await t.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 3);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('phone screenshots', (t) async {
    await t.runAsync(loadFonts);
    t.view.physicalSize = const Size(1080, 2160);
    t.view.devicePixelRatio = 3;
    final app = (await t.runAsync(demo))!;
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: OvrldApp(state: app)));
    await settle(t);
    await shoot(t, key, 'screen-1-today.png');

    for (final (tab, file) in [('WEEK', 'screen-5-week.png'), ('REPORTS', 'screen-6-reports.png'), ('HISTORY', 'screen-7-history.png')]) {
      await t.tap(find.text(tab));
      await settle(t, 22);
      await shoot(t, key, file);
    }

    // Logger: two squat sets done at today's target, then +2.5 for a PR.
    final legs = app.templateFor(app.dayFor(DateTime.now()))!;
    final sid = (await t.runAsync(() async {
      final id = await app.repo.startSession(t: legs);
      await app.changed();
      return id;
    }))!;
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => SessionScreen(sessionId: sid)));
    await settle(t);
    for (var i = 0; i < 2; i++) {
      await t.tap(find.textContaining('LOG SET'));
      await settle(t);
      await t.tap(find.text('SKIP REST'));
      await settle(t);
    }
    await t.tap(find.text('+2.5'));
    await settle(t);
    await shoot(t, key, 'screen-2-log.png');

    // Rest screen.
    await t.tap(find.textContaining('LOG SET'));
    await settle(t, 8);
    await shoot(t, key, 'screen-3-rest.png');
    await t.tap(find.text('SKIP REST'));
    await settle(t);

    // A real session lasts about an hour, not the seconds this script takes.
    await t.runAsync(() async {
      final f = await app.repo.fullSession(sid);
      f.session.startedAt = DateTime.now().subtract(const Duration(minutes: 58, seconds: 21));
      await app.repo.updateSession(f.session);
    });
    nav.pushReplacement(MaterialPageRoute(builder: (_) => FinishScreen(sessionId: sid)));
    await settle(t);
    await t.tap(find.text('STRONG'));
    await settle(t);
    await t.tap(find.text('4'));
    await settle(t);
    await shoot(t, key, 'screen-4-done.png');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('feature graphic and icon', (t) async {
    await t.runAsync(loadFonts);
    t.view.physicalSize = const Size(1024, 500);
    t.view.devicePixelRatio = 1;
    final key = GlobalKey();
    const letters = [('O', 125.0, 900.0), ('V', 62.0, 900.0), ('R', 90.0, 300.0), ('L', 62.0, 200.0), ('D', 125.0, 900.0)];
    const bars = [SplitColors.legs, SplitColors.push, SplitColors.pull, SplitColors.upper, SplitColors.cardio];
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: Container(
          color: Tone.ground,
          padding: const EdgeInsets.fromLTRB(64, 40, 64, 44),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                child: Row(children: [
                  for (final (ch, w, wt) in letters) Text(ch, style: display(300, wdth: w, wght: wt, height: .9)),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              for (final c in bars) Expanded(child: Container(height: 12, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)))),
            ]),
            const SizedBox(height: 22),
            Text('Log kg × reps. Beat last time. Plan the week.', style: mono(30, color: Tone.bone, weight: FontWeight.w500)),
          ]),
        ),
      ),
    ));
    await t.pump();
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/feature-graphic-1024x500.png') // converted to .jpg for upload.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
