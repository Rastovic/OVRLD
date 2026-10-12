import 'package:flutter/material.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/analytics.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';
import 'finish_screen.dart';
import 'today_screen.dart' show supersetLabels;

class SessionDetail extends StatelessWidget {
  const SessionDetail({super.key, required this.sessionId});
  final int sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [
        Builder(builder: (context) => IconButton(
          tooltip: 'Delete workout',
          icon: const Icon(Icons.delete_outline, color: Tone.mute),
          onPressed: () async {
            final app = AppScope.read(context);
            if (!await confirm(context, 'Delete workout', 'Every set in it is deleted. This cannot be undone.')) return;
            await app.repo.deleteSession(sessionId);
            await app.changed();
            if (context.mounted) Navigator.pop(context);
          },
        )),
      ]),
      body: Loader<(FullSession, Map<int, Set<PrKind>>)?>(
        load: (app) async {
          final rows = await app.repo.db.query('session', where: 'id = ?', whereArgs: [sessionId]);
          if (rows.isEmpty) return null;
          final f = await app.repo.fullSession(sessionId);
          return (f, await prsInSession(app.repo, f));
        },
        builder: (context, data) {
          if (data == null) return const SizedBox.shrink();
          final (f, prs) = data;
          final app = AppScope.of(context);
          final s = f.session;
          final color = app.colorOfSession(s);
          final labels = supersetLabels(f.items.map((i) => i.grp).toList());
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
            children: [
              Text('${shortDate(s.startedAt)} · ${_hm(s.startedAt)}${s.offPlan ? ' · extra' : ''}', style: mono(11, color: color)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () async {
                  final n = await askText(context, title: 'Name', initial: s.name);
                  if (n == null) return;
                  s.name = n;
                  await app.repo.updateSession(s);
                  await app.changed();
                },
                child: KText(s.name, size: 54, wdth: 75, wght: 900),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 22, runSpacing: 10, children: [
                _Fact('Time', formatClock(s.durationS), onTap: () => _editDuration(context, s)),
                _Fact('Volume', '${formatThousands(kgToDisplay(app.sessionVolume(f), app.wu))} ${app.wLabel}'),
                _Fact('Sets', '${f.workingSets}'),
                _Fact('PRs', '${prs.length}', color: prs.isEmpty ? Tone.bone : Tone.pr),
                _Fact('Energy', s.energy == null ? '–' : energyWords[s.energy! - 1], onTap: () => _editRatings(context, s)),
                _Fact('Feel', s.feel == null ? '–' : '${s.feel}/5', onTap: () => _editRatings(context, s)),
              ]),
              if (s.note != null) ...[
                const SizedBox(height: 12),
                Text(s.note!, style: mono(13, color: Tone.bone)),
              ],
              const SizedBox(height: 18),
              for (var i = 0; i < f.items.length; i++) ...[
                _ItemBlock(item: f.items[i], label: labels[i], color: color, prs: prs),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editDuration(BuildContext context, Session s) async {
    final app = AppScope.read(context);
    final m = await askNumber(context, title: 'Duration', unit: 'min', initial: (s.durationS / 60).roundToDouble(), decimal: false);
    if (m == null || m <= 0) return;
    s.endedAt = s.startedAt.add(Duration(minutes: m.round()));
    await app.repo.updateSession(s);
    await app.changed();
  }

  Future<void> _editRatings(BuildContext context, Session s) async {
    final app = AppScope.read(context);
    int? energy = s.energy, feel = s.feel;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Lbl('Energy'),
              WordRating(words: energyWords, value: energy, onChanged: (v) => set(() => energy = v)),
              const SizedBox(height: 14),
              const Lbl('Feel'),
              NumberRating(value: feel, words: feelWords, onChanged: (v) => set(() => feel = v)),
              const SizedBox(height: 16),
              BigButton('Save', size: 22, onPressed: () => Navigator.pop(c, true)),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    s
      ..energy = energy
      ..feel = feel;
    await app.repo.updateSession(s);
    await app.changed();
  }
}

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.color = Tone.bone, this.onTap});
  final String label, value;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Lbl(label),
            if (onTap != null) const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.edit_outlined, size: 11, color: Tone.mute),
            ),
          ]),
          Text(value, style: display(24, wdth: 75, wght: 800, color: color)),
        ]),
      );
}

class _ItemBlock extends StatelessWidget {
  const _ItemBlock({required this.item, required this.label, required this.color, required this.prs});
  final SessionItem item;
  final String? label;
  final Color color;
  final Map<int, Set<PrKind>> prs;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final e = app.exercises[item.exerciseId];
    var n = 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tone.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (label != null) Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(label!, style: mono(11, color: color, weight: FontWeight.w600)),
          ),
          Expanded(child: Text((e?.name ?? '?').toUpperCase(), style: display(17, wdth: 80, wght: 800))),
        ]),
        const SizedBox(height: 4),
        if (item.sets.isEmpty) Text('skipped', style: mono(12)),
        for (final s in item.sets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              SizedBox(width: 26, child: Text(s.warmup ? 'W' : '${++n}', style: mono(12))),
              Expanded(
                child: Text(
                  e?.kind == ExerciseKind.time
                      ? '${s.seconds ?? 0} s'
                      : (e?.usesWeight ?? true)
                          ? '${e?.kind == ExerciseKind.bodyweight ? 'BW + ' : ''}${app.w(s.kg)} ${app.wLabel} × ${s.reps}'
                          : '${s.reps} reps',
                  style: mono(13, color: s.warmup ? Tone.mute : Tone.bone),
                ),
              ),
              if (prs[s.id] != null) Stamp(text: prLabel(prs[s.id]!)),
            ]),
          ),
      ]),
    );
  }
}
