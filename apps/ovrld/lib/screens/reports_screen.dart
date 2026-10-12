import 'package:flutter/material.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/models.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../ui/charts.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';

enum Range {
  w4('4W', 28),
  w12('12W', 84),
  m6('6M', 182),
  all('ALL', 0);

  const Range(this.label, this.days);
  final String label;
  final int days;
}

enum Metric { e1rm, top, volume }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Range range = Range.w12;
  int? exerciseId;
  Metric metric = Metric.e1rm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Loader<_Data>(
        load: _Data.load,
        builder: (context, d) {
          final app = AppScope.of(context);
          final today = dateOnly(DateTime.now());
          final from = range == Range.all
              ? (d.firstDate ?? today)
              : addDays(today, -range.days + 1);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
            children: [
              const KText('Reports', size: 44, wdth: 75, wght: 900),
              const SizedBox(height: 10),
              ChoiceRow<Range>(values: Range.values, selected: range, labelOf: (r) => r.label, onChanged: (r) => setState(() => range = r)),
              const SizedBox(height: 14),
              if (d.sessions.isEmpty && d.cardio.isEmpty)
                Panel(child: Text('Finish a workout and your graphs start here: strength per exercise, training days by split, pace, body weight.', style: mono(13)))
              else ...[
                _consistency(app, d, from, today),
                const SizedBox(height: 12),
                _calendar(app, d, today),
                const SizedBox(height: 12),
                _progress(app, d, from),
                const SizedBox(height: 12),
                _muscles(app, d, from),
                if (d.cardio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _cardio(app, d, from, today),
                ],
                const SizedBox(height: 12),
                _energy(app, d, from),
              ],
              const SizedBox(height: 12),
              _bodyWeight(app, d, from),
            ],
          );
        },
      ),
    );
  }

  Widget _title(String t, {String? side, Color? sideColor}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text(t.toUpperCase(), style: display(22, wdth: 75, wght: 800))),
          if (side != null) Text(side, style: mono(11, color: sideColor ?? Tone.mute, weight: FontWeight.w500)),
        ]),
      );

  Widget _consistency(AppState app, _Data d, DateTime from, DateTime today) {
    final plan = app.activePlan;
    final days = <String>{
      for (final s in d.sessions) if (!s.startedAt.isBefore(from)) dayKey(s.startedAt),
      for (final c in d.cardio) if (!c.startedAt.isBefore(from)) dayKey(c.startedAt),
    };
    final weeks = (daysBetween(from, today) + 1) / 7;
    final planned = plan == null ? 0 : (plan.trainingDays * weeks).round();
    final pct = planned == 0 ? null : (days.length / planned * 100).clamp(0, 999).round();
    final allDays = <String>{for (final s in d.sessions) dayKey(s.startedAt), for (final c in d.cardio) dayKey(c.startedAt)};
    final streak = plan == null
        ? 0
        : weekStreak(
            today: today,
            weekComplete: (ws) {
              var n = 0;
              for (var i = 0; i < 7; i++) {
                if (allDays.contains(dayKey(addDays(ws, i)))) n++;
              }
              return n >= plan.trainingDays && plan.trainingDays > 0;
            },
          );
    Widget stat(String l, String v, {Color c = Tone.bone}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Lbl(l),
            KText(v, size: 38, wdth: 75, wght: 850, color: c),
          ]),
        );
    return Panel(
      child: Row(children: [
        stat('Days trained', '${days.length}'),
        stat('Of plan', pct == null ? '–' : '$pct%', c: (pct ?? 0) >= 90 ? Tone.good : Tone.bone),
        stat('Full weeks', '$streak', c: streak > 0 ? Tone.pr : Tone.bone),
      ]),
    );
  }

  Widget _calendar(AppState app, _Data d, DateTime today) {
    final weeks = range == Range.w4 ? 4 : range == Range.w12 ? 12 : range == Range.m6 ? 26 : 26;
    final start = addDays(startOfWeek(today), -7 * (weeks - 1));
    final colorOf = <String, Color>{};
    for (final c in d.cardio) {
      colorOf[dayKey(c.startedAt)] = app.cardioColor;
    }
    for (final s in d.sessions) {
      colorOf[dayKey(s.startedAt)] = app.colorOfSession(s);
    }
    final used = <int, int>{};
    for (final s in d.sessions) {
      if (s.splitId != null && !s.startedAt.isBefore(start)) used[s.splitId!] = (used[s.splitId!] ?? 0) + 1;
    }
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Training days', side: '$weeks weeks'),
        Row(children: [
          for (final w in weekdayShort)
            Expanded(child: Center(child: Text(w[0], style: mono(9.5)))),
        ]),
        const SizedBox(height: 4),
        for (var r = 0; r < weeks; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AspectRatio(
                      aspectRatio: weeks > 12 ? 2.2 : 1.6,
                      child: Builder(builder: (_) {
                        final day = addDays(start, r * 7 + i);
                        final future = day.isAfter(today);
                        final c = colorOf[dayKey(day)];
                        return Container(
                          decoration: BoxDecoration(
                            color: future ? Colors.transparent : (c ?? Tone.raised),
                            border: day == today ? Border.all(color: Tone.bone, width: 1.5) : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
            ]),
          ),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 4, children: [
          for (final e in used.entries)
            if (app.splits[e.key] != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Dot(app.splits[e.key]!.color, size: 9),
                const SizedBox(width: 4),
                Text('${app.splits[e.key]!.name} ${e.value}', style: mono(10.5)),
              ]),
          if (d.cardio.any((c) => !c.startedAt.isBefore(start)))
            Row(mainAxisSize: MainAxisSize.min, children: [
              Dot(app.cardioColor, size: 9),
              const SizedBox(width: 4),
              Text('Cardio ${d.cardio.where((c) => !c.startedAt.isBefore(start)).length}', style: mono(10.5)),
            ]),
        ]),
      ]),
    );
  }

  Widget _progress(AppState app, _Data d, DateTime from) {
    final ids = d.usedExercises.where((id) => app.exercises[id]?.usesWeight ?? false).toList();
    if (ids.isEmpty) return const SizedBox.shrink();
    final id = ids.contains(exerciseId) ? exerciseId! : ids.first;
    final e = app.exercises[id]!;
    final bySession = <int, List<LoggedSet>>{};
    for (final s in d.sets.where((s) => s.exerciseId == id && !s.set.warmup)) {
      bySession.putIfAbsent(s.sessionId, () => []).add(s);
    }
    final points = <(DateTime, double)>[];
    final bests = Bests();
    for (final list in bySession.values) {
      for (final s in list) {
        bests.add(s.set.result);
      }
      final date = list.first.sessionStart;
      if (date.isBefore(from)) continue;
      final value = switch (metric) {
        Metric.e1rm => list.map((s) => e1rm(s.set.kg, s.set.reps) ?? 0).reduce((a, b) => a > b ? a : b),
        Metric.top => list.map((s) => s.set.kg).reduce((a, b) => a > b ? a : b),
        Metric.volume => list.fold<double>(0, (a, s) => a + app.setVolume(e, s.set)),
      };
      if (value > 0) points.add((date, kgToDisplay(value, app.wu)));
    }
    points.sort((a, b) => a.$1.compareTo(b.$1));
    final change = points.length < 2 ? null : points.last.$2 - points.first.$2;
    final color = app.colorOfSessionId(d, bySession.keys.isEmpty ? null : bySession.keys.last);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(
          'Progress',
          side: change == null ? null : '${change >= 0 ? '+' : ''}${formatNumber(change, maxDecimals: 1)} ${app.wLabel}',
          sideColor: (change ?? 0) >= 0 ? Tone.good : Tone.danger,
        ),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final x in ids)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(app.exercises[x]!.name, style: mono(11.5, color: x == id ? Tone.ground : Tone.bone)),
                  selected: x == id,
                  showCheckmark: false,
                  selectedColor: Tone.bone,
                  backgroundColor: Tone.raised,
                  side: const BorderSide(color: Tone.line),
                  onSelected: (_) => setState(() => exerciseId = x),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        ChoiceRow<Metric>(
          values: Metric.values,
          selected: metric,
          labelOf: (m) => switch (m) {
            Metric.e1rm => 'Est. 1RM',
            Metric.top => 'Top set',
            Metric.volume => 'Volume',
          },
          onChanged: (m) => setState(() => metric = m),
        ),
        const SizedBox(height: 12),
        LineChart(points: points, color: color, format: (v) => formatNumber(v, maxDecimals: 1)),
        const SizedBox(height: 8),
        Text(
          bests.isEmpty
              ? ''
              : 'Best est. 1RM ${app.wWithUnit(bests.bestE1rm)} · heaviest ${app.wWithUnit(bests.heaviest)}',
          style: mono(11),
        ),
      ]),
    );
  }

  Widget _muscles(AppState app, _Data d, DateTime from) {
    final counts = <String, int>{};
    for (final s in d.sets) {
      if (s.set.warmup || s.sessionStart.isBefore(from)) continue;
      final m = app.exercises[s.exerciseId]?.muscle;
      if (m == null) continue;
      counts[m] = (counts[m] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();
    final weeks = ((daysBetween(from, DateTime.now()) + 1) / 7).clamp(1, 1e9);
    final rows = counts.entries.map((e) => (e.key, e.value / weeks)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Sets per muscle', side: 'per week'),
        HBars(rows: rows, color: Tone.bone, format: (v) => v.toStringAsFixed(v < 10 ? 1 : 0)),
        const SizedBox(height: 6),
        Text('Working sets only. 10–20 a week per muscle is a common growth range.', style: mono(10.5)),
      ]),
    );
  }

  Widget _cardio(AppState app, _Data d, DateTime from, DateTime today) {
    final runs = d.cardio
        .where((c) => c.activity == CardioActivity.run && c.distanceM > 0 && !c.startedAt.isBefore(from))
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final pace = [
      for (final c in runs) (c.startedAt, paceSeconds(c.durationS, c.distanceM, app.du)!),
    ];
    final weeks = range == Range.w4 ? 4 : 8;
    final ws = startOfWeek(today);
    final bars = <(String, double)>[
      for (var i = weeks - 1; i >= 0; i--)
        (
          'W${isoWeek(addDays(ws, -7 * i))}',
          d.cardio
              .where((c) => startOfWeek(c.startedAt) == addDays(ws, -7 * i))
              .fold<double>(0, (a, c) => a + metresToDisplay(c.distanceM, app.du)),
        ),
    ];
    final best = pace.isEmpty ? null : pace.map((p) => p.$2).reduce((a, b) => a < b ? a : b);
    final avg = pace.isEmpty ? null : pace.map((p) => p.$2).reduce((a, b) => a + b) / pace.length;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Running', side: best == null ? null : 'best ${formatClock(best)} /${app.dLabel}', sideColor: app.cardioColor),
        if (avg != null) Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          KText(formatClock(avg), size: 48, wdth: 70, wght: 900, color: app.cardioColor),
          const SizedBox(width: 8),
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('/${app.dLabel} average · ${pace.length} runs', style: mono(11))),
        ]),
        if (pace.length > 1) ...[
          const SizedBox(height: 8),
          LineChart(points: pace, color: app.cardioColor, format: formatClock, invert: true, height: 120),
          Text('Pace: higher on the chart is faster.', style: mono(10.5)),
        ],
        const SizedBox(height: 12),
        Lbl('All cardio, ${app.dLabel} per week'),
        const SizedBox(height: 6),
        BarChart(bars: bars, color: app.cardioColor, format: (v) => formatNumber(v, maxDecimals: 1)),
      ]),
    );
  }

  Widget _energy(AppState app, _Data d, DateTime from) {
    final pts = <(double, int)>[
      for (final s in d.sessions)
        if (s.energy != null && !s.startedAt.isBefore(from) && (d.volume[s.id] ?? 0) > 0)
          (kgToDisplay(d.volume[s.id]!, app.wu), s.energy!),
    ];
    if (pts.length < 3) return const SizedBox.shrink();
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Energy vs volume', side: '${pts.length} sessions'),
        Scatter(points: pts, color: Tone.bone, formatX: (v) => '${formatThousands(v)} ${app.wLabel}'),
      ]),
    );
  }

  Widget _bodyWeight(AppState app, _Data d, DateTime from) {
    final pts = [
      for (final b in d.bodyWeights)
        if (!b.date.isBefore(from) || range == Range.all) (b.date, kgToDisplay(b.kg, app.wu)),
    ];
    final change = pts.length < 2 ? null : pts.last.$2 - pts.first.$2;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Body weight', side: change == null ? null : '${change >= 0 ? '+' : ''}${formatNumber(change, maxDecimals: 1)} ${app.wLabel}'),
        if (pts.isEmpty)
          Text('Add your weight in the YOU tab to see the trend.', style: mono(12))
        else
          LineChart(points: pts, color: Tone.bone, format: (v) => formatNumber(v, maxDecimals: 1), height: 120),
      ]),
    );
  }
}

class _Data {
  _Data(this.sessions, this.sets, this.cardio, this.bodyWeights, this.usedExercises, this.volume);
  final List<Session> sessions;
  final List<LoggedSet> sets;
  final List<Cardio> cardio;
  final List<BodyWeight> bodyWeights;
  final List<int> usedExercises;
  final Map<int, double> volume;

  DateTime? get firstDate {
    final all = [...sessions.map((s) => s.startedAt), ...cardio.map((c) => c.startedAt)];
    if (all.isEmpty) return null;
    return dateOnly(all.reduce((a, b) => a.isBefore(b) ? a : b));
  }

  static Future<_Data> load(AppState app) async {
    final sets = await app.repo.loggedSets();
    final volume = <int, double>{};
    for (final s in sets) {
      volume[s.sessionId] = (volume[s.sessionId] ?? 0) + app.setVolume(app.exercises[s.exerciseId], s.set);
    }
    return _Data(
      await app.repo.allSessions(),
      sets,
      await app.repo.cardio(),
      await app.repo.bodyWeights(),
      await app.repo.usedExerciseIds(),
      volume,
    );
  }
}

extension on AppState {
  Color colorOfSessionId(_Data d, int? id) {
    final s = d.sessions.where((x) => x.id == id).firstOrNull;
    return s == null ? Tone.bone : colorOfSession(s);
  }
}
