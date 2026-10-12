import 'package:flutter/material.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/models.dart';
import '../data/repo.dart';
import '../services/widget_sync.dart';
import '../ui/tokens.dart';

/// The small amount of state every screen needs: profile, units, splits,
/// exercises, workouts, the active plan. Screens load their own lists through
/// [Loader], which re-runs whenever [revision] moves.
class AppState extends ChangeNotifier {
  AppState(this.repo);
  final Repo repo;

  Profile profile = Profile();
  List<SplitTag> splitList = [];
  Map<int, SplitTag> splits = {};
  Map<int, Exercise> exercises = {};
  List<Template> templates = [];
  Map<int, Template> templateById = {};
  List<Plan> plans = [];
  double? bodyWeightKg;
  Session? openSession;
  int revision = 0;

  Plan? get activePlan => plans.where((p) => p.active).firstOrNull;

  Future<void> load() async {
    profile = await repo.profile();
    splitList = await repo.splits();
    splits = {for (final s in splitList) s.id: s};
    exercises = {for (final e in await repo.exercises()) e.id: e};
    templates = await repo.templates();
    templateById = {for (final t in templates) t.id!: t};
    plans = await repo.plans();
    final bw = await repo.bodyWeights();
    bodyWeightKg = bw.isEmpty ? null : bw.last.kg;
    openSession = await repo.openSession();
    revision++;
    notifyListeners();
    WidgetSync.push(this);
  }

  /// Call after any write.
  Future<void> changed() => load();

  // ---- units

  WeightUnit get wu => profile.weightUnit;
  DistanceUnit get du => profile.distanceUnit;
  String get wLabel => weightLabel(wu);
  String get dLabel => distanceLabel(du);
  String w(double kg) => formatWeight(kg, wu);
  String wWithUnit(double kg) => '${w(kg)} $wLabel';

  // ---- plan days

  PlanDay? dayFor(DateTime d) => activePlan?.days[weekdayIndex(d)];

  Template? templateFor(PlanDay? d) =>
      d?.kind == DayKind.workout ? templateById[d!.templateId] : null;

  String dayTitle(PlanDay? d) => switch (d?.kind) {
        DayKind.workout => templateFor(d)?.name ?? 'Workout',
        DayKind.cardio => d!.cardio?.label ?? 'Cardio',
        _ => 'Rest',
      };

  /// The one word a plan day shows in big type: the split name, else the
  /// workout name.
  String dayWord(PlanDay? d) => switch (d?.kind) {
        DayKind.workout => splits.of(templateFor(d)?.splitId)?.name ?? templateFor(d)?.name ?? 'Workout',
        DayKind.cardio => d!.cardio?.label ?? 'Cardio',
        _ => 'Rest',
      };

  Color dayColor(PlanDay? d) => switch (d?.kind) {
        DayKind.workout => splits.of(templateFor(d)?.splitId)?.color ?? Tone.bone,
        DayKind.cardio => cardioColor,
        _ => SplitColors.rest,
      };

  Color get cardioColor =>
      splitList.where((s) => s.name == 'Cardio').firstOrNull?.color ?? SplitColors.cardio;

  Color colorOfSession(Session s) => splits.of(s.splitId)?.color ?? Tone.bone;

  /// Volume of one set in kg: bodyweight exercises carry the body too.
  double setVolume(Exercise? e, SetEntry s) {
    if (s.warmup) return 0;
    if (e?.kind == ExerciseKind.bodyweight) return (s.kg + (bodyWeightKg ?? 0)) * s.reps;
    if (e?.kind == ExerciseKind.weightReps) return s.kg * s.reps;
    return 0;
  }

  double sessionVolume(FullSession f) => f.items.fold(
        0,
        (sum, i) => sum + i.sets.fold(0.0, (a, s) => a + setVolume(exercises[i.exerciseId], s)),
      );
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Runs [load] once per app revision and keeps showing the last result while
/// the next one loads, so a save never flashes the screen empty.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<T> Function(AppState app) load;
  final Widget Function(BuildContext context, T data) builder;
  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  int? rev;
  T? data;
  bool has = false;
  Object? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (rev != app.revision) {
      rev = app.revision;
      final mine = rev;
      widget.load(app).then((v) {
        if (!mounted || mine != rev) return;
        setState(() {
          data = v;
          has = true;
          error = null;
        });
      }, onError: (Object e) {
        if (mounted) setState(() => error = e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null && !has) {
      return Center(child: Text('Could not load: $error', style: mono(12)));
    }
    if (!has) return const SizedBox.shrink();
    return widget.builder(context, data as T);
  }
}
