import 'package:flutter/material.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/seed.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';
import 'today_screen.dart' show supersetLabels;

Future<void> openReady(BuildContext context, {bool plans = false}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReadyScreen(plans: plans)));

/// Ready-made workouts and weeks, about an hour a session, for anyone who
/// would rather not build their own. Adding one copies it: edit freely after.
class ReadyScreen extends StatefulWidget {
  const ReadyScreen({super.key, this.plans = false});
  final bool plans;
  @override
  State<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends State<ReadyScreen> {
  late bool plans = widget.plans;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('READY-MADE')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
        children: [
          Text('About an hour each. Big lifts first, small ones paired to save time. Add one and change anything.',
              style: mono(12)),
          const SizedBox(height: 12),
          Segment(values: const ['Workouts', 'Weekly plans'], selected: plans ? 1 : 0, onChanged: (i) => setState(() => plans = i == 1)),
          const SizedBox(height: 14),
          if (plans)
            for (final p in readyPlans) ...[_PlanCard(plan: p), const SizedBox(height: 12)]
          else
            for (final w in readyWorkouts) ...[
              _WorkoutCard(workout: w, added: app.templates.any((t) => t.name == w.name)),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout, required this.added});
  final ReadyWorkout workout;
  final bool added;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final w = workout;
    final color = app.splitList.where((s) => s.name == w.split).firstOrNull?.color ?? Tone.bone;
    final byName = {for (final e in app.exercises.values) e.name: e};
    final sets = w.items.fold<int>(0, (a, i) => a + i.$2);
    final labels = supersetLabels(w.items.map((i) => i.$5).toList());
    final hits = <String>{for (final i in w.items) ?byName[i.$1]?.muscle}..remove('Full body');
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Dot(color, size: 10, radius: 5),
          const SizedBox(width: 6),
          Expanded(child: Text(w.split.toUpperCase(), style: label(color: color))),
          Text('~${workoutMinutes(sets)} MIN · $sets SETS', style: label()),
        ]),
        const SizedBox(height: 6),
        KText(w.name, size: 34, wdth: 70, wght: 850, color: color),
        const SizedBox(height: 6),
        Text(w.about, style: mono(11.5, height: 1.45)),
        const SizedBox(height: 10),
        for (var k = 0; k < w.items.length; k++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              SizedBox(width: 24, child: Text(labels[k] ?? '', style: mono(10.5, color: color, weight: FontWeight.w600))),
              Expanded(child: Text(w.items[k].$1, style: mono(12, color: Tone.bone), overflow: TextOverflow.ellipsis)),
              Text(
                byName[w.items[k].$1]?.kind.name == 'time'
                    ? '${w.items[k].$2} × hold'
                    : '${w.items[k].$2} × ${w.items[k].$3}–${w.items[k].$4}',
                style: mono(11),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Text('Works: ${hits.join(', ')}', style: mono(10.5, height: 1.45)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: GhostButton(
            added ? 'In your workouts' : 'Add to my workouts',
            icon: added ? Icons.check : Icons.add,
            onPressed: added
                ? null
                : () async {
                    await app.repo.addReadyWorkout(w);
                    await app.changed();
                    if (context.mounted) toast(context, '${w.name} added. Put it on a day in WEEK.');
                  },
          ),
        ),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final ReadyPlan plan;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = plan;
    final ready = {for (final w in readyWorkouts) w.name: w};
    final colorOf = {for (final s in app.splitList) s.name: s.color};
    final days = p.week.where((d) => d != null && d != 'cardio').length;
    final using = app.activePlan?.name == p.name;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$days WORKOUTS · ~$days H A WEEK', style: label()),
        const SizedBox(height: 6),
        KText(p.name, size: 34, wdth: 70, wght: 850),
        const SizedBox(height: 6),
        Text(p.about, style: mono(11.5, height: 1.45)),
        const SizedBox(height: 10),
        for (var i = 0; i < 7; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tone.line))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(width: 40, child: Text(weekdayShort[i], style: mono(10.5))),
              Expanded(
                child: switch (p.week[i]) {
                  null => Text('REST', style: display(18, wdth: 70, wght: 200, color: SplitColors.rest, height: 1.1)),
                  'cardio' => Text('RUN', style: display(18, wdth: 70, wght: 800, color: app.cardioColor, height: 1.1)),
                  final n => Text(
                      n.toUpperCase(),
                      style: display(18, wdth: 70, wght: 800, color: colorOf[ready[n]?.split] ?? Tone.bone, height: 1.1),
                      overflow: TextOverflow.ellipsis,
                    ),
                },
              ),
            ]),
          ),
        const SizedBox(height: 12),
        BigButton(
          using ? 'Your plan' : 'Use this plan',
          size: 20,
          onPressed: using
              ? null
              : () async {
                  await app.repo.addReadyPlan(p);
                  await app.changed();
                  if (context.mounted) {
                    toast(context, '${p.name} is your plan now. Your old plans are kept in WEEK.');
                    Navigator.pop(context);
                  }
                },
        ),
      ]),
    );
  }
}
