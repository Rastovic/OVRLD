import 'package:flutter/material.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';
import 'cardio_screen.dart';
import 'flow.dart';
import 'session_detail.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Loader<List<_Week>>(
        load: _load,
        builder: (context, weeks) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          children: [
            Row(children: [
              const Expanded(child: KText('History', size: 44, wdth: 75, wght: 900)),
              GhostButton('Cardio', icon: Icons.add, onPressed: () => openCardio(context)),
            ]),
            const SizedBox(height: 10),
            if (weeks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Text('Finished workouts and cardio show up here, week by week.', style: mono(13)),
              ),
            for (final w in weeks) _WeekBlock(w: w),
          ],
        ),
      ),
    );
  }

  static Future<List<_Week>> _load(AppState app) async {
    final sessions = await app.repo.allSessions();
    final cardio = await app.repo.cardio();
    final weeks = <DateTime, _Week>{};
    _Week wk(DateTime d) => weeks.putIfAbsent(startOfWeek(d), () => _Week(startOfWeek(d)));
    // One read for every set, rather than one query per session: history
    // grows by a few sessions a week, forever.
    final volume = <int, double>{};
    final sets = <int, int>{};
    for (final l in await app.repo.loggedSets()) {
      volume[l.sessionId] = (volume[l.sessionId] ?? 0) + app.setVolume(app.exercises[l.exerciseId], l.set);
      if (!l.set.warmup) sets[l.sessionId] = (sets[l.sessionId] ?? 0) + 1;
    }
    for (final s in sessions) {
      final w = wk(s.startedAt);
      final v = volume[s.id] ?? 0;
      w.entries.add(_Entry(session: s, volume: v, sets: sets[s.id] ?? 0));
      w.seconds += s.durationS;
      w.volume += v;
      if (s.energy != null) w.energies.add(s.energy!);
    }
    for (final c in cardio) {
      final w = wk(c.startedAt);
      w.entries.add(_Entry(cardio: c));
      w.seconds += c.durationS;
      if (c.energy != null) w.energies.add(c.energy!);
    }
    for (final w in weeks.values) {
      w.entries.sort((a, b) => b.at.compareTo(a.at));
    }
    return weeks.values.toList()..sort((a, b) => b.start.compareTo(a.start));
  }
}

class _Week {
  _Week(this.start);
  final DateTime start;
  final entries = <_Entry>[];
  int seconds = 0;
  double volume = 0;
  final energies = <int>[];
  int get days => entries.map((e) => dayKey(e.at)).toSet().length;
}

class _Entry {
  _Entry({this.session, this.cardio, this.volume = 0, this.sets = 0});
  final Session? session;
  final Cardio? cardio;
  final double volume;
  final int sets;
  DateTime get at => session?.startedAt ?? cardio!.startedAt;
}

class _WeekBlock extends StatelessWidget {
  const _WeekBlock({required this.w});
  final _Week w;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final end = addDays(w.start, 6);
    final planned = app.activePlan?.trainingDays ?? 0;
    final avg = w.energies.isEmpty ? null : w.energies.reduce((a, b) => a + b) / w.energies.length;
    final isThis = w.start == startOfWeek(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '${isThis ? 'THIS WEEK' : 'WEEK ${isoWeek(w.start)}'} · ${w.start.day} ${monthShort[w.start.month - 1]}–${end.day} ${monthShort[end.month - 1]}',
          style: label(color: Tone.bone),
        ),
        const SizedBox(height: 2),
        Text(
          [
            '${w.days}${planned > 0 ? '/$planned' : ''} days',
            formatHoursMinutes(w.seconds),
            if (w.volume > 0) '${formatThousands(kgToDisplay(w.volume, app.wu))} ${app.wLabel}',
            if (avg != null) 'energy ${avg.toStringAsFixed(1)}',
          ].join(' · '),
          style: mono(11),
        ),
        const SizedBox(height: 6),
        for (final e in w.entries) _EntryRow(e: e),
      ]),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.e});
  final _Entry e;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = e.session;
    final c = e.cardio;
    final color = s != null ? app.colorOfSession(s) : app.cardioColor;
    final title = s?.name ?? c!.activity.label;
    final right = s != null
        ? '${formatClock(s.durationS)}\n${formatThousands(kgToDisplay(e.volume, app.wu))} ${app.wLabel} · ${e.sets} sets'
        : '${formatClock(c!.durationS)}\n${[distanceText(app, c), paceText(app, c)].where((x) => x.isNotEmpty).join(' · ')}';
    return InkWell(
      onTap: () => s != null
          ? Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetail(sessionId: s.id)))
          : openCardio(context, existing: c),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tone.line))),
        child: Row(children: [
          Container(width: 4, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(shortDate(e.at), style: mono(10.5)),
              Text(title.toUpperCase(), style: display(19, wdth: 80, wght: 800), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Text(right, style: mono(11, color: Tone.bone), textAlign: TextAlign.right),
        ]),
      ),
    );
  }
}
