import 'package:flutter/material.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';
import 'flow.dart';
import 'workout_editor.dart';

class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final plan = app.activePlan;
    final today = dateOnly(DateTime.now());
    final week = startOfWeek(today);
    final end = addDays(week, 6);
    return SafeArea(
      child: Loader<_WeekData>(
        load: _WeekData.load,
        builder: (context, data) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  'WEEK ${isoWeek(today)} · ${week.day}${week.month != end.month ? ' ${monthShort[week.month - 1]}' : ''}–${end.day} ${monthShort[end.month - 1]}',
                  style: mono(11),
                ),
              ),
              InkWell(
                onTap: () => _plans(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('PLAN: ${plan?.name.toUpperCase() ?? 'NONE'}', style: mono(11, color: Tone.bone, weight: FontWeight.w500)),
                    const Icon(Icons.expand_more, size: 16, color: Tone.bone),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            if (plan == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const KText('No plan yet', size: 64, wdth: 62, wght: 200),
                  const SizedBox(height: 10),
                  Text('A plan is your week: a workout, cardio or rest for each day.', style: mono(13)),
                  const SizedBox(height: 16),
                  GhostButton('Make a plan', icon: Icons.add, onPressed: () => _newPlan(context)),
                ]),
              )
            else
              for (var i = 0; i < 7; i++)
                _DayRow(
                  index: i,
                  day: plan.days[i],
                  date: addDays(week, i),
                  today: addDays(week, i) == today,
                  done: data.doneColors[dayKey(addDays(week, i))],
                ),
            const SizedBox(height: 26),
            Row(children: [
              const Expanded(child: Lbl('Workouts')),
              GhostButton('New', icon: Icons.add, onPressed: () => openWorkoutEditor(context, null)),
            ]),
            const SizedBox(height: 4),
            for (final t in app.templates)
              InkWell(
                onTap: () => openWorkoutEditor(context, t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tone.line))),
                  child: Row(children: [
                    Dot(app.splits[t.splitId]?.color ?? Tone.bone, size: 12),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.name.toUpperCase(), style: display(19, wdth: 80, wght: 800))),
                    Text('${t.items.length} ex', style: mono(11)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Tone.mute, size: 18),
                  ]),
                ),
              ),
            if (app.templates.isEmpty) Text('No workouts yet. Make one, then put it on a day.', style: mono(12)),
            const SizedBox(height: 26),
            const Lbl('Previous weeks'),
            const SizedBox(height: 8),
            for (final w in data.past) _PastWeek(w: w),
            if (data.past.isEmpty) Text('Your finished weeks will line up here.', style: mono(12)),
          ],
        ),
      ),
    );
  }

  Future<void> _plans(BuildContext context) async {
    final app = AppScope.read(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            const Lbl('Plans'),
            for (final p in app.plans)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.name.toUpperCase(), style: display(22, wdth: 80, wght: p.active ? 900 : 500, color: p.active ? Tone.bone : Tone.mute)),
                subtitle: Text(p.active ? 'Active · week ${p.weekNumber(DateTime.now())}' : '${p.trainingDays} training days', style: mono(11)),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Tone.mute),
                  onSelected: (v) async {
                    Navigator.pop(c);
                    if (v == 'rename') {
                      final n = await askText(context, title: 'Plan name', initial: p.name);
                      if (n == null) return;
                      p.name = n;
                      await app.repo.savePlan(p);
                    } else if (v == 'copy') {
                      await app.repo.savePlan(Plan(
                        name: '${p.name} copy',
                        days: [for (final d in p.days) PlanDay(weekday: d.weekday, kind: d.kind, templateId: d.templateId, cardio: d.cardio, note: d.note)],
                      ));
                    } else if (v == 'delete') {
                      if (!context.mounted || !await confirm(context, 'Delete plan', 'Workouts and history stay. Only the week layout goes.')) return;
                      await app.repo.deletePlan(p.id!);
                    }
                    await app.changed();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text('Rename', style: mono(13, color: Tone.bone))),
                    PopupMenuItem(value: 'copy', child: Text('Duplicate', style: mono(13, color: Tone.bone))),
                    PopupMenuItem(value: 'delete', child: Text('Delete', style: mono(13, color: Tone.danger))),
                  ],
                ),
                onTap: () async {
                  Navigator.pop(c);
                  if (!p.active) {
                    await app.repo.activatePlan(p.id!);
                    await app.changed();
                  }
                },
              ),
            const SizedBox(height: 8),
            GhostButton('New plan', icon: Icons.add, onPressed: () {
              Navigator.pop(c);
              _newPlan(context);
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _newPlan(BuildContext context) async {
    final app = AppScope.read(context);
    final n = await askText(context, title: 'New plan', hint: 'e.g. Upper/Lower, Deload');
    if (n == null) return;
    await app.repo.savePlan(Plan(name: n, active: true));
    await app.changed();
  }
}

class _WeekData {
  _WeekData(this.doneColors, this.past);

  /// dayKey → colour of what was done that day.
  final Map<String, Color> doneColors;
  final List<_PastWeekData> past;

  static Future<_WeekData> load(AppState app) async {
    final now = DateTime.now();
    final from = addDays(startOfWeek(now), -7 * 12);
    final sessions = await app.repo.sessionsBetween(from, addDays(startOfWeek(now), 7));
    final cardio = await app.repo.cardio(from: from);
    final done = <String, Color>{};
    final perWeek = <DateTime, _PastWeekData>{};
    _PastWeekData wk(DateTime d) => perWeek.putIfAbsent(startOfWeek(d), () => _PastWeekData(startOfWeek(d)));
    for (final c in cardio) {
      done[dayKey(c.startedAt)] = app.cardioColor;
      wk(c.startedAt)
        ..days[weekdayIndex(c.startedAt)] = app.cardioColor
        ..seconds += c.durationS;
    }
    for (final s in sessions.reversed) {
      done[dayKey(s.startedAt)] = app.colorOfSession(s);
      wk(s.startedAt)
        ..days[weekdayIndex(s.startedAt)] = app.colorOfSession(s)
        ..seconds += s.durationS
        ..energies.addAll([if (s.energy != null) s.energy!]);
    }
    final thisWeek = startOfWeek(now);
    final past = perWeek.values.where((w) => w.start.isBefore(thisWeek)).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return _WeekData(done, past);
  }
}

class _PastWeekData {
  _PastWeekData(this.start);
  final DateTime start;
  final days = List<Color?>.filled(7, null);
  int seconds = 0;
  final energies = <int>[];
  int get count => days.whereType<Color>().length;
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.index, required this.day, required this.date, required this.today, required this.done});
  final int index;
  final PlanDay day;
  final DateTime date;
  final bool today;
  final Color? done;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final word = app.dayWord(day);
    final rest = day.kind == DayKind.rest;
    final t = app.templateFor(day);
    final meta = switch (day.kind) {
      DayKind.workout => '${t?.items.length ?? 0} ex',
      DayKind.cardio => day.note ?? '',
      DayKind.rest => '',
    };
    // Short words set wide, long words narrow, so every row reads as one block.
    final wd = (125 - (word.length - 4) * 9).clamp(62, 125).toDouble();
    return InkWell(
      onTap: () => _editDay(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tone.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 46,
            child: Row(children: [
              Flexible(
                child: Text(weekdayShort[index], maxLines: 1, overflow: TextOverflow.clip,
                    style: mono(10.5, color: today ? Tone.bone : Tone.mute, weight: today ? FontWeight.w600 : FontWeight.w400)),
              ),
              if (today) Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(left: 4),
                decoration: const BoxDecoration(color: Tone.bone, shape: BoxShape.circle),
              ),
            ]),
          ),
          Expanded(
            child: VaryText(
              word,
              size: 46,
              wdth: rest ? 90 : wd,
              wght: rest ? 150 : 850,
              fromWdth: 62,
              color: app.dayColor(day),
              delay: Duration(milliseconds: 80 * index),
              duration: const Duration(milliseconds: 1100),
            ),
          ),
          const SizedBox(width: 8),
          if (done != null) Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(Icons.check_circle, size: 16, color: done),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(meta, style: mono(10.5), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }

  Future<void> _editDay(BuildContext context) async {
    final app = AppScope.read(context);
    final plan = app.activePlan!;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Lbl('${weekdayShort[index]} · ${shortDate(date)}'),
              const SizedBox(height: 6),
              if (day.kind != DayKind.rest)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(spacing: 8, children: [
                    GhostButton('Start now', icon: Icons.play_arrow, onPressed: () => Navigator.pop(c, 'start')),
                    if (day.kind == DayKind.workout && app.templateFor(day) != null)
                      GhostButton('Edit workout', icon: Icons.edit_outlined, onPressed: () => Navigator.pop(c, 'edit')),
                  ]),
                ),
              const Lbl('Set this day to'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Dot(SplitColors.rest, size: 14, radius: 4),
                title: Text('REST', style: display(22, wdth: 90, wght: 200)),
                onTap: () => Navigator.pop(c, 'rest'),
              ),
              for (final t in app.templates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Dot(app.splits[t.splitId]?.color ?? Tone.bone, size: 14, radius: 4),
                  title: Text(t.name.toUpperCase(), style: display(22, wdth: 80, wght: 800)),
                  subtitle: Text('${t.items.length} exercises', style: mono(11)),
                  trailing: day.templateId == t.id && day.kind == DayKind.workout ? const Icon(Icons.check, color: Tone.bone) : null,
                  onTap: () => Navigator.pop(c, t),
                ),
              for (final a in CardioActivity.values.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Dot(app.cardioColor, size: 14, radius: 4),
                  title: Text(a.label.toUpperCase(), style: display(22, wdth: 80, wght: 800)),
                  subtitle: Text('Cardio', style: mono(11)),
                  trailing: day.kind == DayKind.cardio && day.cardio == a ? const Icon(Icons.check, color: Tone.bone) : null,
                  onTap: () => Navigator.pop(c, a),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add, color: Tone.bone),
                title: Text('New workout…', style: mono(14, color: Tone.bone)),
                onTap: () => Navigator.pop(c, 'new'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'start') {
      if (day.kind == DayKind.cardio) return openCardio(context, activity: day.cardio);
      return startWorkout(context, t: app.templateFor(day), offPlan: !today);
    }
    if (choice == 'edit') {
      await openWorkoutEditor(context, app.templateFor(day));
      return;
    }
    if (choice == 'new') {
      final id = await openWorkoutEditor(context, null);
      if (id == null) return;
      day
        ..kind = DayKind.workout
        ..templateId = id;
    } else if (choice == 'rest') {
      day
        ..kind = DayKind.rest
        ..templateId = null;
    } else if (choice is Template) {
      day
        ..kind = DayKind.workout
        ..templateId = choice.id;
    } else if (choice is CardioActivity) {
      String? note = day.kind == DayKind.cardio ? day.note : null;
      if (context.mounted) {
        note = await askText(context, title: 'Target (optional)', initial: note ?? '', hint: 'e.g. 5 km easy, 30 min intervals') ?? note;
      }
      day
        ..kind = DayKind.cardio
        ..cardio = choice
        ..note = note;
    }
    await app.repo.savePlan(plan);
    await app.changed();
  }
}

class _PastWeek extends StatelessWidget {
  const _PastWeek({required this.w});
  final _PastWeekData w;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final planned = app.activePlan?.trainingDays ?? 0;
    final avg = w.energies.isEmpty ? null : w.energies.reduce((a, b) => a + b) / w.energies.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 42, child: Text('W${isoWeek(w.start)}', style: mono(11))),
        for (final c in w.days) Padding(padding: const EdgeInsets.only(right: 3), child: Dot(c, size: 11)),
        const Spacer(),
        Text(
          '${w.count}${planned > 0 ? '/$planned' : ''} · ${formatHoursMinutes(w.seconds)}${avg == null ? '' : ' · energy ${avg.toStringAsFixed(1)}'}',
          style: mono(11),
        ),
      ]),
    );
  }
}
