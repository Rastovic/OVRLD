import 'package:ovrld_core/ovrld_core.dart';
import 'package:sqflite/sqflite.dart';

import '../ui/tokens.dart';
import 'models.dart';
import 'schema.dart';
import 'seed.dart';

/// Everything OVRLD stores, behind one class. Storage is kg / metres /
/// seconds / epoch ms; the screen converts.
class Repo {
  Repo(this.db);
  final Database db;

  /// [factory] is for tests (in-memory ffi); each test then gets its own
  /// database instead of sharing one cached instance.
  static Future<Repo> open(String path, {DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        singleInstance: factory == null,
        onCreate: (db, v) async {
          final b = db.batch();
          for (final s in createStatements) {
            b.execute(s);
          }
          await b.commit(noResult: true);
          await _seed(db);
        },
        onUpgrade: (db, from, to) async {
          for (var v = from + 1; v <= to; v++) {
            for (final s in migrations[v] ?? const <String>[]) {
              await db.execute(s);
            }
          }
        },
      ),
    );
    return Repo(db);
  }

  static Future<void> _seed(DatabaseExecutor db) async {
    await db.insert('profile', Profile().toRow());
    var i = 0;
    for (final (name, color) in seedSplits) {
      await db.insert('split_tag', {'name': name, 'color': color.toARGB32(), 'sort': i++});
    }
    for (final (name, muscle, equipment, kind) in seedExercises) {
      await db.insert('exercise', {
        'name': name,
        'muscle': muscle,
        'equipment': equipment,
        'kind': kind,
        'increment_kg': kind == 'reps' || kind == 'time' ? 0 : defaultIncrement(equipment),
      });
    }
  }

  // ---------------------------------------------------------------- profile

  Future<Profile> profile() async =>
      Profile.fromRow((await db.query('profile', where: 'id = 1')).single);

  Future<void> saveProfile(Profile p) =>
      db.update('profile', p.toRow(), where: 'id = 1');

  Future<List<BodyWeight>> bodyWeights() async => [
        for (final r in await db.query('body_weight', orderBy: 'date ASC, id ASC'))
          BodyWeight(
            id: r['id'] as int,
            date: DateTime.parse(r['date'] as String),
            kg: (r['kg'] as num).toDouble(),
          ),
      ];

  /// One reading per day: a second entry on the same day replaces the first.
  Future<void> addBodyWeight(DateTime date, double kg) async {
    await db.transaction((tx) async {
      await tx.delete('body_weight', where: 'date = ?', whereArgs: [dayKey(date)]);
      await tx.insert('body_weight', {'date': dayKey(date), 'kg': kg});
    });
  }

  Future<void> deleteBodyWeight(int id) =>
      db.delete('body_weight', where: 'id = ?', whereArgs: [id]);

  // ---------------------------------------------------------------- splits

  Future<List<SplitTag>> splits() async => [
        for (final r in await db.query('split_tag', orderBy: 'sort, id')) SplitTag.fromRow(r),
      ];

  Future<int> addSplit(String name, int color) async {
    final sort = Sqflite.firstIntValue(await db.rawQuery('SELECT COALESCE(MAX(sort), 0) + 1 FROM split_tag')) ?? 0;
    return db.insert('split_tag', {'name': name, 'color': color, 'sort': sort});
  }

  Future<void> updateSplit(SplitTag s) => db.update(
        'split_tag',
        {'name': s.name, 'color': s.color.toARGB32(), 'sort': s.sort},
        where: 'id = ?',
        whereArgs: [s.id],
      );

  Future<void> resetSplitColors() async {
    for (final (name, color) in seedSplits) {
      await db.update('split_tag', {'color': color.toARGB32()}, where: 'name = ?', whereArgs: [name]);
    }
  }

  // ---------------------------------------------------------------- exercises

  Future<List<Exercise>> exercises() async => [
        for (final r in await db.query('exercise', orderBy: 'name COLLATE NOCASE')) Exercise.fromRow(r),
      ];

  Future<int> addExercise({
    required String name,
    required String muscle,
    required String equipment,
    required ExerciseKind kind,
    required double incrementKg,
  }) =>
      db.insert('exercise', {
        'name': name,
        'muscle': muscle,
        'equipment': equipment,
        'kind': kind.name,
        'increment_kg': incrementKg,
        'custom': 1,
      });

  Future<void> updateExercise(Exercise e) => db.update(
        'exercise',
        {
          'name': e.name,
          'muscle': e.muscle,
          'equipment': e.equipment,
          'kind': e.kind.name,
          'increment_kg': e.incrementKg,
          'archived': e.archived ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [e.id],
      );

  // ---------------------------------------------------------------- templates

  Future<List<Template>> templates() async {
    final rows = await db.query('template', where: 'archived = 0', orderBy: 'id');
    final items = await db.query('template_item', orderBy: 'template_id, pos');
    final byTemplate = <int, List<TemplateItem>>{};
    for (final r in items) {
      byTemplate.putIfAbsent(r['template_id'] as int, () => []).add(TemplateItem.fromRow(r));
    }
    return [
      for (final r in rows)
        Template(
          id: r['id'] as int,
          name: r['name'] as String,
          splitId: r['split_id'] as int?,
          items: byTemplate[r['id']] ?? [],
        ),
    ];
  }

  Future<int> saveTemplate(Template t) => db.transaction((tx) async {
        final row = {'name': t.name, 'split_id': t.splitId};
        final id = t.id ?? await tx.insert('template', row);
        if (t.id != null) await tx.update('template', row, where: 'id = ?', whereArgs: [id]);
        await tx.delete('template_item', where: 'template_id = ?', whereArgs: [id]);
        for (var i = 0; i < t.items.length; i++) {
          final it = t.items[i];
          await tx.insert('template_item', {
            'template_id': id,
            'exercise_id': it.exerciseId,
            'pos': i,
            'sets': it.sets,
            'rep_min': it.repMin,
            'rep_max': it.repMax,
            'rest_s': it.restS,
            'grp': it.grp,
          });
        }
        t.id = id;
        return id;
      });

  /// Archived, not deleted: past sessions keep their own copy of the
  /// exercises, but the name still links them to a workout in history.
  Future<void> archiveTemplate(int id) => db.transaction((tx) async {
        await tx.update('template', {'archived': 1}, where: 'id = ?', whereArgs: [id]);
        await tx.update('plan_day', {'kind': DayKind.rest.name, 'template_id': null},
            where: 'template_id = ?', whereArgs: [id]);
      });

  // ---------------------------------------------------------------- plans

  Future<List<Plan>> plans() async {
    final rows = await db.query('plan', orderBy: 'id');
    final days = await db.query('plan_day');
    return [
      for (final r in rows)
        Plan(
          id: r['id'] as int,
          name: r['name'] as String,
          active: (r['active'] as int) == 1,
          startedOn: DateTime.parse(r['started_on'] as String),
          days: List.generate(7, (i) {
            final d = days.where((x) => x['plan_id'] == r['id'] && x['weekday'] == i).firstOrNull;
            if (d == null) return PlanDay(weekday: i);
            return PlanDay(
              weekday: i,
              kind: DayKind.values.byName(d['kind'] as String),
              templateId: d['template_id'] as int?,
              cardio: d['cardio'] == null ? null : CardioActivity.values.byName(d['cardio'] as String),
              note: d['note'] as String?,
            );
          }),
        ),
    ];
  }

  Future<Plan?> activePlan() async => (await plans()).where((p) => p.active).firstOrNull;

  Future<int> savePlan(Plan p) => db.transaction((tx) async {
        final row = {'name': p.name, 'active': p.active ? 1 : 0, 'started_on': dayKey(p.startedOn)};
        if (p.active) await tx.update('plan', {'active': 0});
        final id = p.id ?? await tx.insert('plan', row);
        if (p.id != null) await tx.update('plan', row, where: 'id = ?', whereArgs: [id]);
        await tx.delete('plan_day', where: 'plan_id = ?', whereArgs: [id]);
        for (final d in p.days) {
          await tx.insert('plan_day', {
            'plan_id': id,
            'weekday': d.weekday,
            'kind': d.kind.name,
            'template_id': d.kind == DayKind.workout ? d.templateId : null,
            'cardio': d.kind == DayKind.cardio ? (d.cardio ?? CardioActivity.run).name : null,
            'note': d.note,
          });
        }
        p.id = id;
        return id;
      });

  Future<void> activatePlan(int id) => db.transaction((tx) async {
        await tx.update('plan', {'active': 0});
        await tx.update('plan', {'active': 1, 'started_on': dayKey(DateTime.now())},
            where: 'id = ?', whereArgs: [id]);
      });

  Future<void> deletePlan(int id) => db.transaction((tx) async {
        await tx.delete('plan_day', where: 'plan_id = ?', whereArgs: [id]);
        await tx.delete('plan', where: 'id = ?', whereArgs: [id]);
      });

  /// Builds the ready-made PPL+ plan from the seeded exercises.
  Future<void> createStarterPlan() async {
    final ex = {for (final e in await exercises()) e.name: e.id};
    final sp = {for (final s in await splits()) s.name: s.id};
    final ids = <String, int>{};
    for (final (split, name, items) in starterTemplates) {
      ids[name] = await saveTemplate(Template(
        name: name,
        splitId: sp[split],
        items: [
          for (final (exName, sets, min, max, grp) in items)
            TemplateItem(exerciseId: ex[exName]!, sets: sets, repMin: min, repMax: max, grp: grp),
        ],
      ));
    }
    await savePlan(Plan(
      name: 'PPL+',
      active: true,
      days: [
        for (var i = 0; i < 7; i++)
          switch (starterWeek[i]) {
            null => PlanDay(weekday: i),
            'cardio' => PlanDay(weekday: i, kind: DayKind.cardio, cardio: CardioActivity.run, note: '5 km easy'),
            final name => PlanDay(weekday: i, kind: DayKind.workout, templateId: ids[name]),
          },
      ],
    ));
  }

  // ---------------------------------------------------------------- sessions

  Future<Session?> openSession() async {
    final r = await db.query('session', where: 'ended_at IS NULL', orderBy: 'started_at DESC', limit: 1);
    return r.isEmpty ? null : Session.fromRow(r.first);
  }

  /// Starts a session as a snapshot of [t]: editing the workout later never
  /// rewrites what was done in this one.
  Future<int> startSession({Template? t, String? name, int? splitId, bool offPlan = false}) =>
      db.transaction((tx) async {
        final id = await tx.insert('session', {
          'template_id': t?.id,
          'split_id': t?.splitId ?? splitId,
          'name': t?.name ?? name ?? 'Workout',
          'started_at': DateTime.now().millisecondsSinceEpoch,
          'off_plan': offPlan ? 1 : 0,
        });
        final items = t?.items ?? const <TemplateItem>[];
        for (var i = 0; i < items.length; i++) {
          final it = items[i];
          await tx.insert('session_item', {
            'session_id': id,
            'exercise_id': it.exerciseId,
            'pos': i,
            'grp': it.grp,
            'sets_planned': it.sets,
            'rep_min': it.repMin,
            'rep_max': it.repMax,
            'rest_s': it.restS,
          });
        }
        return id;
      });

  Future<FullSession> fullSession(int id) async {
    final s = Session.fromRow((await db.query('session', where: 'id = ?', whereArgs: [id])).single);
    final items = [
      for (final r in await db.query('session_item', where: 'session_id = ?', whereArgs: [id], orderBy: 'pos'))
        SessionItem.fromRow(r),
    ];
    if (items.isNotEmpty) {
      final sets = await db.query(
        'set_entry',
        where: 'item_id IN (${List.filled(items.length, '?').join(',')})',
        whereArgs: [for (final i in items) i.id],
        orderBy: 'idx, id',
      );
      final byItem = {for (final i in items) i.id: i};
      for (final r in sets) {
        byItem[r['item_id']]!.sets.add(SetEntry.fromRow(r));
      }
    }
    return FullSession(s, items);
  }

  Future<int> addItem(int sessionId, int exerciseId, {required int repMin, required int repMax, int sets = 3, int? grp}) async {
    final pos = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COALESCE(MAX(pos), -1) + 1 FROM session_item WHERE session_id = ?', [sessionId])) ??
        0;
    return db.insert('session_item', {
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'pos': pos,
      'grp': grp,
      'sets_planned': sets,
      'rep_min': repMin,
      'rep_max': repMax,
    });
  }

  Future<void> updateItem(SessionItem i) => db.update(
        'session_item',
        {'pos': i.pos, 'grp': i.grp, 'sets_planned': i.setsPlanned, 'rep_min': i.repMin, 'rep_max': i.repMax},
        where: 'id = ?',
        whereArgs: [i.id],
      );

  Future<void> removeItem(int itemId) => db.transaction((tx) async {
        await tx.delete('set_entry', where: 'item_id = ?', whereArgs: [itemId]);
        await tx.delete('session_item', where: 'id = ?', whereArgs: [itemId]);
      });

  /// Written per set, not at the end: a killed app or a dead phone mid-
  /// session loses nothing already logged.
  Future<int> addSet(int itemId, {required int idx, required double kg, required int reps, int? seconds, double? rpe, bool warmup = false}) =>
      db.insert('set_entry', {
        'item_id': itemId,
        'idx': idx,
        'kg': kg,
        'reps': reps,
        'seconds': seconds,
        'rpe': rpe,
        'warmup': warmup ? 1 : 0,
        'done_at': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> updateSet(SetEntry s) => db.update(
        'set_entry',
        {'kg': s.kg, 'reps': s.reps, 'seconds': s.seconds, 'rpe': s.rpe, 'warmup': s.warmup ? 1 : 0},
        where: 'id = ?',
        whereArgs: [s.id],
      );

  Future<void> deleteSet(int id) => db.delete('set_entry', where: 'id = ?', whereArgs: [id]);

  Future<void> finishSession(int id, {int? energy, int? feel, String? note, DateTime? endedAt}) => db.update(
        'session',
        {
          'ended_at': (endedAt ?? DateTime.now()).millisecondsSinceEpoch,
          'energy': energy,
          'feel': feel,
          'note': note,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> updateSession(Session s) => db.update(
        'session',
        {
          'name': s.name,
          'split_id': s.splitId,
          'started_at': s.startedAt.millisecondsSinceEpoch,
          'ended_at': s.endedAt?.millisecondsSinceEpoch,
          'energy': s.energy,
          'feel': s.feel,
          'note': s.note,
        },
        where: 'id = ?',
        whereArgs: [s.id],
      );

  Future<void> deleteSession(int id) => db.transaction((tx) async {
        await tx.rawDelete(
            'DELETE FROM set_entry WHERE item_id IN (SELECT id FROM session_item WHERE session_id = ?)', [id]);
        await tx.delete('session_item', where: 'session_id = ?', whereArgs: [id]);
        await tx.delete('session', where: 'id = ?', whereArgs: [id]);
      });

  /// Finished sessions started in [from, to).
  Future<List<Session>> sessionsBetween(DateTime from, DateTime to) async => [
        for (final r in await db.query(
          'session',
          where: 'ended_at IS NOT NULL AND started_at >= ? AND started_at < ?',
          whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
          orderBy: 'started_at DESC',
        ))
          Session.fromRow(r),
      ];

  Future<List<Session>> allSessions() async => [
        for (final r in await db.query('session', where: 'ended_at IS NOT NULL', orderBy: 'started_at DESC'))
          Session.fromRow(r),
      ];

  /// Every logged set of finished sessions, with the session start and the
  /// exercise. One flat read, which is what reports want.
  Future<List<LoggedSet>> loggedSets({int? exerciseId, int? excludeSession}) async {
    final where = <String>['s.ended_at IS NOT NULL'];
    final args = <Object?>[];
    if (exerciseId != null) {
      where.add('i.exercise_id = ?');
      args.add(exerciseId);
    }
    if (excludeSession != null) {
      where.add('s.id != ?');
      args.add(excludeSession);
    }
    final rows = await db.rawQuery('''
      SELECT e.*, i.exercise_id, i.session_id, i.rep_min, i.rep_max, i.sets_planned, s.started_at
      FROM set_entry e
      JOIN session_item i ON i.id = e.item_id
      JOIN session s ON s.id = i.session_id
      WHERE ${where.join(' AND ')}
      ORDER BY s.started_at, e.idx, e.id
    ''', args);
    return [
      for (final r in rows)
        LoggedSet(
          set: SetEntry.fromRow(r),
          exerciseId: r['exercise_id'] as int,
          sessionId: r['session_id'] as int,
          sessionStart: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
          repMin: r['rep_min'] as int,
          repMax: r['rep_max'] as int,
          setsPlanned: r['sets_planned'] as int,
        ),
    ];
  }

  /// The most recent finished session containing [exerciseId], whatever
  /// workout it was in - that is what "last time" means.
  Future<LastTime?> lastTime(int exerciseId, {int? excludeSession}) async {
    final sets = await loggedSets(exerciseId: exerciseId, excludeSession: excludeSession);
    if (sets.isEmpty) return null;
    final lastSession = sets.last.sessionId;
    final mine = sets.where((s) => s.sessionId == lastSession).toList();
    return LastTime(
      date: mine.first.sessionStart,
      sets: [for (final s in mine) s.set],
      repMin: mine.first.repMin,
      repMax: mine.first.repMax,
      setsPlanned: mine.first.setsPlanned,
      allHistory: [for (final s in sets) s.set.result],
    );
  }

  /// Exercise ids with at least one finished set, most recently used first.
  Future<List<int>> usedExerciseIds() async => [
        for (final r in await db.rawQuery('''
          SELECT i.exercise_id AS id, MAX(s.started_at) AS last
          FROM session_item i JOIN session s ON s.id = i.session_id
          JOIN set_entry e ON e.item_id = i.id
          WHERE s.ended_at IS NOT NULL
          GROUP BY i.exercise_id ORDER BY last DESC
        '''))
          r['id'] as int,
      ];

  // ---------------------------------------------------------------- cardio

  Future<List<Cardio>> cardio({DateTime? from, DateTime? to}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('started_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('started_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    return [
      for (final r in await db.query('cardio',
          where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'started_at DESC'))
        Cardio.fromRow(r),
    ];
  }

  Future<int> saveCardio(Cardio c) async {
    final row = {
      'activity': c.activity.name,
      'started_at': c.startedAt.millisecondsSinceEpoch,
      'duration_s': c.durationS,
      'distance_m': c.distanceM,
      'avg_hr': c.avgHr,
      'energy': c.energy,
      'note': c.note,
    };
    if (c.id == null) {
      c.id = await db.insert('cardio', row);
    } else {
      await db.update('cardio', row, where: 'id = ?', whereArgs: [c.id]);
    }
    return c.id!;
  }

  Future<void> deleteCardio(int id) => db.delete('cardio', where: 'id = ?', whereArgs: [id]);

  // ---------------------------------------------------------------- backup

  Future<Map<String, Object?>> exportAll() async => {
        'app': 'ovrld',
        'schema': schemaVersion,
        'exported_at': DateTime.now().toIso8601String(),
        'tables': {for (final t in allTables) t: await db.query(t)},
      };

  /// Replaces everything with [data], all or nothing.
  Future<void> importAll(Map<String, Object?> data) async {
    if (data['app'] != 'ovrld') throw const FormatException('This file is not an OVRLD backup.');
    final schema = data['schema'] as int? ?? 0;
    if (schema > schemaVersion) {
      throw const FormatException('This backup is from a newer version of OVRLD. Update the app first.');
    }
    final tables = (data['tables'] as Map).cast<String, Object?>();
    await db.transaction((tx) async {
      for (final t in allTables.reversed) {
        await tx.delete(t);
      }
      for (final t in allTables) {
        for (final r in (tables[t] as List? ?? const [])) {
          await tx.insert(t, (r as Map).cast<String, Object?>());
        }
      }
    });
  }
}

class LoggedSet {
  LoggedSet({
    required this.set,
    required this.exerciseId,
    required this.sessionId,
    required this.sessionStart,
    required this.repMin,
    required this.repMax,
    required this.setsPlanned,
  });
  final SetEntry set;
  final int exerciseId;
  final int sessionId;
  final DateTime sessionStart;
  final int repMin, repMax, setsPlanned;
}

class LastTime {
  LastTime({
    required this.date,
    required this.sets,
    required this.repMin,
    required this.repMax,
    required this.setsPlanned,
    required this.allHistory,
  });
  final DateTime date;
  final List<SetEntry> sets;
  final int repMin, repMax, setsPlanned;

  /// Every finished set ever, for PR checks.
  final List<SetResult> allHistory;

  List<SetEntry> get working => sets.where((s) => !s.warmup).toList();
}

/// Split tag colour, or the rest grey when a session has none.
extension SplitLookup on Map<int, SplitTag> {
  SplitTag? of(int? id) => id == null ? null : this[id];
}

const restColor = SplitColors.rest;
