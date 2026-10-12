import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ovrld/data/models.dart';
import 'package:ovrld/data/repo.dart';
import 'package:ovrld/main.dart';
import 'package:ovrld/screens/cardio_screen.dart';
import 'package:ovrld/screens/exercise_picker.dart';
import 'package:ovrld/screens/flow.dart';
import 'package:ovrld/screens/session_screen.dart';
import 'package:ovrld/screens/workout_editor.dart';
import 'package:ovrld/screens/tour.dart';
import 'package:ovrld/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppState> seeded() async {
  sqfliteFfiInit();
  final repo = await Repo.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
  await repo.createStarterPlan();
  final p = await repo.profile()
    ..name = 'Jelena'
    ..onboarded = true
    ..tourSeen = true;
  await repo.saveProfile(p);
  await repo.addBodyWeight(DateTime.now(), 64);
  final app = AppState(repo);
  await app.load();
  return app;
}

/// Small phone: 360 × 760 dp. Overflows throw in tests, so rendering every
/// screen here is the layout check.
void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2280);
  t.view.devicePixelRatio = 3;
  t.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(t.view.reset);
}

/// Scroll to [text] first, as a person would on a small screen.
Future<void> press(WidgetTester t, String text) async {
  final f = find.text(text).last;
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('every tab renders on a small phone', (t) async {
    phone(t);
    final app = (await t.runAsync(seeded))!;
    await t.pumpWidget(OvrldApp(state: app));
    await settle(t);
    for (final tab in ['WEEK', 'HISTORY', 'REPORTS', 'YOU', 'TODAY']) {
      await t.tap(find.text(tab));
      await settle(t);
      expect(t.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('a whole workout: log sets, superset, finish, rate', (t) async {
    phone(t);
    final app = (await t.runAsync(seeded))!;
    final legs = app.templates.firstWhere((x) => x.name == 'Leg day');
    final sid = (await t.runAsync(() => app.repo.startSession(t: legs)))!;
    await t.runAsync(app.changed);
    await t.pumpWidget(OvrldApp(state: app));
    await settle(t);
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => SessionScreen(sessionId: sid)));
    await settle(t);
    expect(find.text('BACK SQUAT'), findsOneWidget);

    await t.tap(find.text('+2.5'));
    await settle(t);
    await press(t, 'LOG SET 1');
    await settle(t);
    // Rest overlay after a single-exercise set.
    expect(find.text('SKIP REST'), findsOneWidget);
    await press(t, 'SKIP REST');
    await settle(t);
    expect(find.text('LOG SET 2'), findsOneWidget);

    final full = (await t.runAsync(() => app.repo.fullSession(sid)))!;
    expect(full.items.first.sets.single.kg, 22.5, reason: 'first-time barbell starts at the empty bar + 2.5');

    // Jump to the superset (walking lunge A1) and check alternation.
    await t.tap(find.text('Exercises'));
    await settle(t);
    await t.tap(find.text('WALKING LUNGE'));
    await settle(t);
    expect(find.textContaining('SUPERSET A1'), findsOneWidget);
    await press(t, 'LOG SET 1');
    await settle(t);
    expect(find.text('SKIP REST'), findsNothing, reason: 'no rest inside a superset round');
    // Moved to A2: its first set, not A1's second.
    expect(find.text('LOG SET 1'), findsOneWidget);
    expect(find.text('LOG SET 2'), findsNothing);
    await press(t, 'LOG SET 1');
    await settle(t);
    expect(find.text('SKIP REST'), findsOneWidget, reason: 'rest once the round is done');
    await press(t, 'SKIP REST');
    await settle(t);
    // Back on A1 for round two.
    expect(find.text('LOG SET 2'), findsOneWidget);

    await press(t, 'FINISH');
    await settle(t);
    expect(find.text('DONE.'), findsOneWidget);
    await press(t, 'STRONG');
    await settle(t);
    await t.scrollUntilVisible(find.text('SAVE'), 200, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('SAVE'));
    await settle(t);
    final s = (await t.runAsync(() => app.repo.fullSession(sid)))!.session;
    expect(s.open, isFalse);
    expect(s.energy, 4);
    expect(t.takeException(), isNull);

    // Detail and history now have a finished session to draw.
    for (final tab in ['HISTORY', 'REPORTS']) {
      await t.tap(find.text(tab));
      await settle(t);
    }
    await t.tap(find.text('HISTORY'));
    await settle(t);
    await t.tap(find.text('LEG DAY').last);
    await settle(t);
    expect(find.text('PRS'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('walkthrough opens on first visit, pages through, and is remembered', (t) async {
    phone(t);
    final app = (await t.runAsync(seeded))!;
    app.profile.tourSeen = false;
    await t.runAsync(() => app.repo.saveProfile(app.profile));
    await t.runAsync(app.changed);
    await t.pumpWidget(OvrldApp(state: app));
    await settle(t);
    expect(find.byType(Tour), findsOneWidget);
    for (var i = 0; i < 7; i++) {
      await press(t, 'NEXT');
      await settle(t);
      expect(t.takeException(), isNull, reason: 'page ${i + 2}');
    }
    await press(t, "LET'S LIFT");
    await settle(t);
    expect(find.byType(Tour), findsNothing);
    expect((await t.runAsync(() => app.repo.profile()))!.tourSeen, isTrue);
  });

  testWidgets('leaving a workout with nothing logged throws it away', (t) async {
    phone(t);
    final app = (await t.runAsync(seeded))!;
    final sid = (await t.runAsync(() => app.repo.startSession(name: 'Workout')))!;
    await t.runAsync(app.changed);
    await t.pumpWidget(OvrldApp(state: app));
    await settle(t);
    t.state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (_) => SessionScreen(sessionId: sid)));
    await settle(t);
    await t.tap(find.byTooltip('Minimise - the session keeps running'));
    await settle(t);
    expect(await t.runAsync(() => app.repo.openSession()), isNull);
  });

  testWidgets('a running workout with sets is not silently resumed by another', (t) async {
    phone(t);
    final app = (await t.runAsync(seeded))!;
    final legs = app.templates.firstWhere((x) => x.name == 'Leg day');
    final push = app.templates.firstWhere((x) => x.name == 'Push day');
    final old = (await t.runAsync(() async {
      final id = await app.repo.startSession(t: legs);
      final item = (await app.repo.fullSession(id)).items.first.id;
      await app.repo.addSet(item, idx: 0, kg: 60, reps: 8);
      await app.changed();
      return id;
    }))!;
    await t.pumpWidget(OvrldApp(state: app));
    await settle(t);
    final ctx = t.element(find.byType(Scaffold).first);
    startWorkout(ctx, t: push);
    await settle(t);
    expect(find.textContaining('STILL RUNNING'), findsOneWidget);
    await t.tap(find.text('Discard, start new'));
    await settle(t);
    final open = (await t.runAsync(() => app.repo.openSession()))!;
    expect(open.id, isNot(old));
    expect(open.name, 'Push day');
  });

  testWidgets('QUICK WORKOUT button with no plan opens the logger', (t) async {
    phone(t);
    final app = (await t.runAsync(seeded))!;
    await t.runAsync(() async {
      await app.repo.deletePlan(app.activePlan!.id!);
      // A forgotten empty workout from earlier, like on her phone.
      await app.repo.startSession(name: 'Workout');
      await app.changed();
    });
    await t.pumpWidget(OvrldApp(state: app));
    await settle(t);
    expect(find.text('QUICK WORKOUT'), findsOneWidget);
    await press(t, 'QUICK WORKOUT');
    await settle(t);
    await t.tap(find.text('Empty workout'));
    await settle(t);
    expect(find.byType(SessionScreen), findsOneWidget);
    expect(find.text('ADD EXERCISE'), findsOneWidget);
    final open = (await t.runAsync(() => app.repo.openSession()))!;
    expect(DateTime.now().difference(open.startedAt).inSeconds, lessThan(30), reason: 'fresh clock');
    expect((await t.runAsync(() => app.repo.db.query('session')))!.length, 1, reason: 'old empty one deleted');
  });

  testWidgets('START button on a planned day opens the logger', (t) async {
    phone(t);
    final app = (await t.runAsync(seeded))!;
    // Make every day Leg day so the test does not depend on the weekday.
    final plan = app.activePlan!;
    final legs = app.templates.firstWhere((x) => x.name == 'Leg day');
    for (final d in plan.days) {
      d
        ..kind = DayKind.workout
        ..templateId = legs.id;
    }
    await t.runAsync(() async {
      await app.repo.savePlan(plan);
      await app.changed();
    });
    await t.pumpWidget(OvrldApp(state: app));
    await settle(t);
    await press(t, 'START');
    await settle(t);
    expect(find.byType(SessionScreen), findsOneWidget);
    expect(find.text('BACK SQUAT'), findsOneWidget);
  });

  testWidgets('removing an exercise keeps other supersets intact', (t) async {
    phone(t);
    final app = (await t.runAsync(seeded))!;
    await t.pumpWidget(OvrldApp(state: app));
    await settle(t);
    final push = app.templates.firstWhere((x) => x.name == 'Push day');
    t.state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (_) => WorkoutEditor(template: push)));
    await settle(t);
    expect(find.text('A1'), findsOneWidget);
    // Bench, OHP, incline, [lateral + pushdown]: remove OHP.
    await t.ensureVisible(find.byTooltip('Remove').at(1));
    await t.pump();
    await t.tap(find.byTooltip('Remove').at(1));
    await settle(t);
    expect(find.text('OVERHEAD PRESS'), findsNothing);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('A2'), findsOneWidget);
    // Remove the lateral raise: the pushdown is left alone, no superset.
    await t.ensureVisible(find.byTooltip('Remove').at(2));
    await t.pump();
    await t.tap(find.byTooltip('Remove').at(2));
    await settle(t);
    expect(find.text('LATERAL RAISE'), findsNothing);
    expect(find.text('A1'), findsNothing);
  });

  testWidgets('editors and forms render', (t) async {
    phone(t);
    final app = (await t.runAsync(seeded))!;
    await t.pumpWidget(OvrldApp(state: app));
    await settle(t);
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    for (final page in <Widget>[
      const CardioScreen(),
      WorkoutEditor(template: app.templates.firstWhere((x) => x.name == 'Upper day')),
      const WorkoutEditor(),
      const ExercisePicker(manage: true),
    ]) {
      nav.push(MaterialPageRoute(builder: (_) => page));
      await settle(t);
      expect(t.takeException(), isNull, reason: page.runtimeType.toString());
      nav.pop();
      await settle(t);
    }
  });
}
