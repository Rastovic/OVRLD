import 'package:flutter/material.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/models.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';
import 'flow.dart';
import 'session_detail.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateTime.now();
    final plan = app.activePlan;
    final day = app.dayFor(now);
    final t = app.templateFor(day);
    return SafeArea(
      child: Loader<_TodayData>(
        load: (app) => _TodayData.load(app, t),
        builder: (context, data) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Row(children: [
              Expanded(child: Text(shortDate(now), style: mono(11))),
              if (plan != null) Text('WEEK ${plan.weekNumber(now)} · ${plan.name.toUpperCase()}', style: mono(11)),
            ]),
            const SizedBox(height: 14),
            if (app.openSession != null) ...[
              _ResumeCard(session: app.openSession!),
              const SizedBox(height: 18),
            ],
            if (data.doneToday.isNotEmpty || data.cardioToday.isNotEmpty)
              _DoneToday(data: data)
            else if (plan == null)
              const _NoPlan()
            else
              switch (day!.kind) {
                DayKind.workout => _WorkoutDay(template: t, data: data),
                DayKind.cardio => _CardioDay(day: day),
                DayKind.rest => _RestDay(data: data),
              },
          ],
        ),
      ),
    );
  }
}

class _TodayData {
  _TodayData(this.last, this.doneToday, this.cardioToday, this.weekDone, this.weekPlanned);
  final Map<int, LastTime?> last;
  final List<Session> doneToday;
  final List<Cardio> cardioToday;
  final int weekDone, weekPlanned;

  static Future<_TodayData> load(AppState app, Template? t) async {
    final last = <int, LastTime?>{};
    for (final it in t?.items ?? const <TemplateItem>[]) {
      last[it.exerciseId] = await app.repo.lastTime(it.exerciseId);
    }
    final today = dateOnly(DateTime.now());
    final week = startOfWeek(today);
    final sessions = await app.repo.sessionsBetween(week, addDays(week, 7));
    final cardio = await app.repo.cardio(from: week, to: addDays(week, 7));
    final days = <String>{
      for (final s in sessions) dayKey(s.startedAt),
      for (final c in cardio) dayKey(c.startedAt),
    };
    return _TodayData(
      last,
      sessions.where((s) => dateOnly(s.startedAt) == today).toList(),
      cardio.where((c) => dateOnly(c.startedAt) == today).toList(),
      days.length,
      app.activePlan?.trainingDays ?? 0,
    );
  }
}

/// "last 100 × 8·8·7·7 → 100 × 8" for one exercise in a plan.
String lastLine(AppState app, Exercise e, TemplateItem it, LastTime? last) {
  if (last == null) return 'first time · ${it.sets} × ${it.repMin}–${it.repMax}';
  final work = last.working;
  if (work.isEmpty) return 'no working sets last time';
  final reps = work.map((s) => e.kind == ExerciseKind.time ? '${s.seconds ?? 0}s' : '${s.reps}').join('·');
  if (!e.usesWeight) return 'last $reps';
  final topKg = work.map((s) => s.kg).reduce((a, b) => a > b ? a : b);
  final target = nextTarget(
    last: [for (final s in last.sets) s.result],
    repMin: it.repMin,
    repMax: it.repMax,
    incrementKg: e.incrementKg,
    plannedSets: last.setsPlanned,
  );
  final lead = e.kind == ExerciseKind.bodyweight ? 'BW+${app.w(topKg)}' : app.w(topKg);
  final next = target == null ? '' : ' → ${app.w(target.kg)} × ${target.reps}';
  return 'last $lead × $reps$next';
}

class _WorkoutDay extends StatelessWidget {
  const _WorkoutDay({required this.template, required this.data});
  final Template? template;
  final _TodayData data;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = template;
    if (t == null) return const _RestDay.fallback();
    final color = app.splits[t.splitId]?.color ?? Tone.bone;
    final sets = t.items.fold<int>(0, (a, i) => a + i.sets);
    final labels = supersetLabels(t.items.map((i) => i.grp).toList());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(offset: const Offset(-18, 0), child: Marquee(t.name, color: color)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Lbl('${t.items.length} exercises · ~${(sets * 2.5 + 5).round()} min')),
          GhostButton('Not today?', onPressed: () => pickAnyWorkout(context, offPlan: true)),
        ]),
        const SizedBox(height: 6),
        for (var i = 0; i < t.items.length; i++)
          _ExerciseRow(item: t.items[i], label: labels[i], color: color, last: data.last[t.items[i].exerciseId]),
        const SizedBox(height: 18),
        BigButton(app.openSession?.templateId == t.id ? 'Resume' : 'Start', color: color, onPressed: () => startWorkout(context, t: t)),
      ],
    );
  }
}

/// A1 / A2 for the first superset, B1 / B2 for the next; null when alone.
List<String?> supersetLabels(List<int?> groups) {
  final out = List<String?>.filled(groups.length, null);
  var letter = 0;
  var i = 0;
  while (i < groups.length) {
    final g = groups[i];
    var j = i;
    while (g != null && j + 1 < groups.length && groups[j + 1] == g) {
      j++;
    }
    if (j > i) {
      final ch = String.fromCharCode(65 + letter++);
      for (var k = i; k <= j; k++) {
        out[k] = '$ch${k - i + 1}';
      }
    }
    i = j + 1;
  }
  return out;
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.item, required this.label, required this.color, required this.last});
  final TemplateItem item;
  final String? label;
  final Color color;
  final LastTime? last;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final e = app.exercises[item.exerciseId];
    if (e == null) return const SizedBox.shrink();
    final line = lastLine(app, e, item, last);
    final arrow = line.indexOf('→');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tone.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: Text(label!, style: mono(11, color: color, weight: FontWeight.w600)),
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(e.name.toUpperCase(), style: display(16, wdth: 80, wght: 700, height: 1.1))),
              Text('${item.sets} × ${item.repMin}–${item.repMax}', style: mono(11)),
            ]),
            const SizedBox(height: 3),
            Text.rich(TextSpan(children: [
              TextSpan(text: arrow < 0 ? line : line.substring(0, arrow), style: mono(11)),
              if (arrow >= 0) TextSpan(text: line.substring(arrow), style: mono(11, color: color, weight: FontWeight.w500)),
            ])),
          ]),
        ),
      ]),
    );
  }
}

class _CardioDay extends StatelessWidget {
  const _CardioDay({required this.day});
  final PlanDay day;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final a = day.cardio ?? CardioActivity.run;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Transform.translate(offset: const Offset(-18, 0), child: Marquee(a.label, color: app.cardioColor)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Lbl(day.note?.isNotEmpty == true ? day.note! : 'Cardio day')),
        GhostButton('Not today?', onPressed: () => pickAnyWorkout(context, offPlan: true)),
      ]),
      const SizedBox(height: 18),
      Text('Log time and distance when you are back. Pace is worked out for you.', style: mono(12)),
      const SizedBox(height: 22),
      BigButton('Log ${a.label}', color: app.cardioColor, onPressed: () => openCardio(context, activity: a)),
    ]);
  }
}

class _RestDay extends StatelessWidget {
  const _RestDay({required this.data}) : fallback = false;
  const _RestDay.fallback()
      : data = null,
        fallback = true;
  final _TodayData? data;
  final bool fallback;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tomorrow = app.dayFor(addDays(DateTime.now(), 1));
    final tKind = tomorrow?.kind ?? DayKind.rest;
    final tomorrowText = switch (tKind) {
      DayKind.rest => 'rest again',
      DayKind.cardio => app.dayWord(tomorrow).toUpperCase(),
      DayKind.workout => '${app.dayWord(tomorrow).toUpperCase()} · ${app.templateFor(tomorrow)?.items.length ?? 0} exercises',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 30),
      const Breathe('Rest', size: 140),
      const SizedBox(height: 18),
      Text(fallback ? 'The workout planned today was removed.' : 'Nothing planned today.', style: mono(13)),
      const SizedBox(height: 4),
      Text.rich(TextSpan(style: mono(13), children: [
        const TextSpan(text: 'Tomorrow: '),
        TextSpan(text: tomorrowText, style: mono(13, color: app.dayColor(tomorrow), weight: FontWeight.w600)),
      ])),
      if (data != null && data!.weekPlanned > 0) ...[
        const SizedBox(height: 4),
        Text('This week: ${data!.weekDone} of ${data!.weekPlanned} done.', style: mono(13)),
      ],
      const SizedBox(height: 28),
      Wrap(spacing: 8, runSpacing: 8, children: [
        GhostButton('Train anyway', icon: Icons.fitness_center, onPressed: () => pickAnyWorkout(context, offPlan: true)),
        GhostButton('Log cardio', icon: Icons.directions_run, onPressed: () => openCardio(context)),
      ]),
    ]);
  }
}

class _NoPlan extends StatelessWidget {
  const _NoPlan();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 20),
        const KText('No plan', size: 96, wdth: 62, wght: 200),
        const SizedBox(height: 14),
        Text('Make your week in the WEEK tab: pick a workout or rest for each day. Or just train now.', style: mono(13)),
        const SizedBox(height: 24),
        BigButton('Quick workout', onPressed: () => pickAnyWorkout(context, offPlan: true)),
      ]);
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = app.colorOfSession(session);
    return Panel(
      onTap: () => startWorkout(context, resume: true),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Lbl('In progress · started ${_hm(session.startedAt)}', color: c),
            const SizedBox(height: 4),
            KText(session.name, size: 30, wdth: 80, wght: 850),
          ]),
        ),
        Text('RESUME →', style: mono(12, color: Tone.bone, weight: FontWeight.w600)),
      ]),
    );
  }
}

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _DoneToday extends StatelessWidget {
  const _DoneToday({required this.data});
  final _TodayData data;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const VaryText('Done.', size: 110, wdth: 125, wght: 900, fromWdth: 62, fromWght: 300, duration: Duration(milliseconds: 900)),
      const SizedBox(height: 16),
      for (final s in data.doneToday)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Panel(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetail(sessionId: s.id))),
            child: Row(children: [
              Dot(app.colorOfSession(s), size: 12),
              const SizedBox(width: 10),
              Expanded(child: Text(s.name.toUpperCase(), style: display(20, wdth: 80, wght: 800))),
              Text(formatClock(s.durationS), style: mono(12, color: Tone.bone)),
            ]),
          ),
        ),
      for (final c in data.cardioToday)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Panel(
            onTap: () => openCardio(context, existing: c),
            child: Row(children: [
              Dot(app.cardioColor, size: 12),
              const SizedBox(width: 10),
              Expanded(child: Text(c.activity.label.toUpperCase(), style: display(20, wdth: 80, wght: 800))),
              Text(
                '${formatNumber(metresToDisplay(c.distanceM, app.du), maxDecimals: 2)} ${app.dLabel} · ${formatClock(c.durationS)}',
                style: mono(12, color: Tone.bone),
              ),
            ]),
          ),
        ),
      const SizedBox(height: 10),
      Text('Recover well. Tomorrow: ${app.dayTitle(app.dayFor(addDays(DateTime.now(), 1)))}.', style: mono(12)),
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerLeft,
        child: GhostButton('Train again', icon: Icons.add, onPressed: () => pickAnyWorkout(context, offPlan: true)),
      ),
    ]);
  }
}
