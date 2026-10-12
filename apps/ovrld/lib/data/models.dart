import 'package:flutter/painting.dart';
import 'package:ovrld_core/ovrld_core.dart';

/// How an exercise is logged.
/// - weightReps: kg × reps (squat, curl)
/// - bodyweight: body weight plus added kg × reps (pull-up, dip). `kg` holds
///   the added load only; volume adds the body weight of that day.
/// - reps: reps only, no load (burpee)
/// - time: seconds held (plank). `reps` is unused, `seconds` holds the time.
enum ExerciseKind { weightReps, bodyweight, reps, time }

class Exercise {
  Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.equipment,
    required this.kind,
    required this.incrementKg,
    this.archived = false,
    this.custom = false,
  });
  final int id;
  String name;
  String muscle;
  String equipment;
  ExerciseKind kind;
  double incrementKg;
  bool archived;
  bool custom;

  bool get usesWeight => kind == ExerciseKind.weightReps || kind == ExerciseKind.bodyweight;

  factory Exercise.fromRow(Map<String, Object?> r) => Exercise(
        id: r['id'] as int,
        name: r['name'] as String,
        muscle: r['muscle'] as String,
        equipment: r['equipment'] as String,
        kind: ExerciseKind.values.byName(r['kind'] as String),
        incrementKg: (r['increment_kg'] as num).toDouble(),
        archived: (r['archived'] as int) == 1,
        custom: (r['custom'] as int) == 1,
      );
}

class SplitTag {
  SplitTag({required this.id, required this.name, required this.color, required this.sort});
  final int id;
  String name;
  Color color;
  int sort;

  factory SplitTag.fromRow(Map<String, Object?> r) => SplitTag(
        id: r['id'] as int,
        name: r['name'] as String,
        color: Color(r['color'] as int),
        sort: r['sort'] as int,
      );
}

class TemplateItem {
  TemplateItem({
    this.id,
    required this.exerciseId,
    required this.sets,
    required this.repMin,
    required this.repMax,
    this.restS,
    this.grp,
  });
  int? id;
  int exerciseId;
  int sets;
  int repMin;
  int repMax;
  int? restS;

  /// Items sharing a group number are a superset (two) or a circuit (more).
  int? grp;

  factory TemplateItem.fromRow(Map<String, Object?> r) => TemplateItem(
        id: r['id'] as int,
        exerciseId: r['exercise_id'] as int,
        sets: r['sets'] as int,
        repMin: r['rep_min'] as int,
        repMax: r['rep_max'] as int,
        restS: r['rest_s'] as int?,
        grp: r['grp'] as int?,
      );

  TemplateItem copy() => TemplateItem(
        exerciseId: exerciseId, sets: sets, repMin: repMin, repMax: repMax, restS: restS, grp: grp,
      );
}

class Template {
  Template({this.id, required this.name, this.splitId, List<TemplateItem>? items})
      : items = items ?? [];
  int? id;
  String name;
  int? splitId;
  List<TemplateItem> items;
}

enum DayKind { rest, workout, cardio }

class PlanDay {
  PlanDay({required this.weekday, this.kind = DayKind.rest, this.templateId, this.cardio, this.note});
  final int weekday; // 0 = Monday
  DayKind kind;
  int? templateId;
  CardioActivity? cardio;
  String? note;
}

class Plan {
  Plan({this.id, required this.name, this.active = false, DateTime? startedOn, List<PlanDay>? days})
      : startedOn = startedOn ?? dateOnly(DateTime.now()),
        days = days ?? List.generate(7, (i) => PlanDay(weekday: i));
  int? id;
  String name;
  bool active;
  DateTime startedOn;
  List<PlanDay> days;

  int weekNumber(DateTime today) => daysBetween(startOfWeek(startedOn), today) ~/ 7 + 1;
  int get trainingDays => days.where((d) => d.kind != DayKind.rest).length;
}

class Session {
  Session({
    required this.id,
    this.templateId,
    this.splitId,
    required this.name,
    required this.startedAt,
    this.endedAt,
    this.energy,
    this.feel,
    this.note,
    this.offPlan = false,
  });
  final int id;
  int? templateId;
  int? splitId;
  String name;
  DateTime startedAt;
  DateTime? endedAt;
  int? energy; // 1-5
  int? feel; // 1-5
  String? note;
  bool offPlan;

  bool get open => endedAt == null;
  int get durationS => ((endedAt ?? DateTime.now()).difference(startedAt).inSeconds).clamp(0, 1 << 31);

  factory Session.fromRow(Map<String, Object?> r) => Session(
        id: r['id'] as int,
        templateId: r['template_id'] as int?,
        splitId: r['split_id'] as int?,
        name: r['name'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
        endedAt: r['ended_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['ended_at'] as int),
        energy: r['energy'] as int?,
        feel: r['feel'] as int?,
        note: r['note'] as String?,
        offPlan: (r['off_plan'] as int) == 1,
      );
}

class SessionItem {
  SessionItem({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.pos,
    this.grp,
    required this.setsPlanned,
    required this.repMin,
    required this.repMax,
    this.restS,
    List<SetEntry>? sets,
  }) : sets = sets ?? [];
  final int id;
  final int sessionId;
  final int exerciseId;
  int pos;
  int? grp;
  int setsPlanned;
  int repMin;
  int repMax;
  int? restS;
  List<SetEntry> sets;

  factory SessionItem.fromRow(Map<String, Object?> r) => SessionItem(
        id: r['id'] as int,
        sessionId: r['session_id'] as int,
        exerciseId: r['exercise_id'] as int,
        pos: r['pos'] as int,
        grp: r['grp'] as int?,
        setsPlanned: r['sets_planned'] as int,
        repMin: r['rep_min'] as int,
        repMax: r['rep_max'] as int,
        restS: r['rest_s'] as int?,
      );
}

class SetEntry {
  SetEntry({
    required this.id,
    required this.itemId,
    required this.idx,
    required this.kg,
    required this.reps,
    this.seconds,
    this.rpe,
    this.warmup = false,
    required this.doneAt,
  });
  final int id;
  final int itemId;
  int idx;
  double kg;
  int reps;
  int? seconds;
  double? rpe;
  bool warmup;
  DateTime doneAt;

  SetResult get result => SetResult(kg, reps, warmup: warmup);

  factory SetEntry.fromRow(Map<String, Object?> r) => SetEntry(
        id: r['id'] as int,
        itemId: r['item_id'] as int,
        idx: r['idx'] as int,
        kg: (r['kg'] as num).toDouble(),
        reps: r['reps'] as int,
        seconds: r['seconds'] as int?,
        rpe: (r['rpe'] as num?)?.toDouble(),
        warmup: (r['warmup'] as int) == 1,
        doneAt: DateTime.fromMillisecondsSinceEpoch(r['done_at'] as int),
      );
}

/// A session with everything in it, as the logger and the detail screen need.
class FullSession {
  FullSession(this.session, this.items);
  final Session session;
  final List<SessionItem> items;

  Iterable<SetEntry> get allSets => items.expand((i) => i.sets);
  int get workingSets => allSets.where((s) => !s.warmup).length;
}

/// perDistance: min/km (run, walk). speed: km/h (cycle). per100m: swim.
/// per500m: rowing machines all show /500 m.
enum PaceMode { perDistance, speed, per100m, per500m }

extension PaceModeMetres on PaceMode {
  /// Distance is typed in metres for pool and erg, in km/mi otherwise.
  bool get metres => this == PaceMode.per100m || this == PaceMode.per500m;
}

enum CardioActivity {
  run('Run', PaceMode.perDistance),
  walk('Walk', PaceMode.perDistance),
  cycle('Cycle', PaceMode.speed),
  row('Row', PaceMode.per500m),
  swim('Swim', PaceMode.per100m),
  elliptical('Elliptical', PaceMode.speed),
  other('Other', PaceMode.speed);

  const CardioActivity(this.label, this.pace);
  final String label;
  final PaceMode pace;
}

class Cardio {
  Cardio({
    this.id,
    required this.activity,
    required this.startedAt,
    required this.durationS,
    required this.distanceM,
    this.avgHr,
    this.energy,
    this.note,
  });
  int? id;
  CardioActivity activity;
  DateTime startedAt;
  int durationS;
  double distanceM;
  int? avgHr;
  int? energy;
  String? note;

  factory Cardio.fromRow(Map<String, Object?> r) => Cardio(
        id: r['id'] as int,
        activity: CardioActivity.values.byName(r['activity'] as String),
        startedAt: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
        durationS: r['duration_s'] as int,
        distanceM: (r['distance_m'] as num).toDouble(),
        avgHr: r['avg_hr'] as int?,
        energy: r['energy'] as int?,
        note: r['note'] as String?,
      );
}

enum Goal {
  strength('Strength', 3, 6),
  muscle('Muscle', 8, 12),
  general('General fitness', 10, 15);

  const Goal(this.label, this.repMin, this.repMax);
  final String label;
  final int repMin, repMax;
}

enum Experience {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const Experience(this.label);
  final String label;
}

enum Sex {
  female('Female'),
  male('Male'),
  other('Other');

  const Sex(this.label);
  final String label;
}

class Profile {
  Profile({
    this.name = '',
    this.birthDate,
    this.sex,
    this.heightCm,
    this.goal = Goal.muscle,
    this.experience = Experience.intermediate,
    this.weightUnit = WeightUnit.kg,
    this.distanceUnit = DistanceUnit.km,
    this.heightUnit = HeightUnit.cm,
    this.restDefaultS = 90,
    this.onboarded = false,
    this.tourSeen = false,
  });
  String name;
  DateTime? birthDate;
  Sex? sex;
  double? heightCm;
  Goal goal;
  Experience experience;
  WeightUnit weightUnit;
  DistanceUnit distanceUnit;
  HeightUnit heightUnit;
  int restDefaultS;
  bool onboarded;
  bool tourSeen;

  int? ageOn(DateTime today) {
    final b = birthDate;
    if (b == null) return null;
    var age = today.year - b.year;
    if (today.month < b.month || (today.month == b.month && today.day < b.day)) age--;
    return age;
  }

  factory Profile.fromRow(Map<String, Object?> r) => Profile(
        name: r['name'] as String,
        birthDate: r['birth_date'] == null ? null : DateTime.parse(r['birth_date'] as String),
        sex: r['sex'] == null ? null : Sex.values.byName(r['sex'] as String),
        heightCm: (r['height_cm'] as num?)?.toDouble(),
        goal: Goal.values.byName(r['goal'] as String),
        experience: Experience.values.byName(r['experience'] as String),
        weightUnit: WeightUnit.values.byName(r['weight_unit'] as String),
        distanceUnit: DistanceUnit.values.byName(r['distance_unit'] as String),
        heightUnit: HeightUnit.values.byName(r['height_unit'] as String),
        restDefaultS: r['rest_default_s'] as int,
        onboarded: (r['onboarded'] as int) == 1,
        tourSeen: ((r['tour_seen'] as int?) ?? 0) == 1,
      );

  Map<String, Object?> toRow() => {
        'id': 1,
        'name': name,
        'birth_date': birthDate == null ? null : dayKey(birthDate!),
        'sex': sex?.name,
        'height_cm': heightCm,
        'goal': goal.name,
        'experience': experience.name,
        'weight_unit': weightUnit.name,
        'distance_unit': distanceUnit.name,
        'height_unit': heightUnit.name,
        'rest_default_s': restDefaultS,
        'onboarded': onboarded ? 1 : 0,
        'tour_seen': tourSeen ? 1 : 0,
      };
}

class BodyWeight {
  BodyWeight({required this.id, required this.date, required this.kg});
  final int id;
  final DateTime date;
  final double kg;
}
