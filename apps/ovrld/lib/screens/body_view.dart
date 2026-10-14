import 'package:flutter/material.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/insights.dart';
import '../state/app_state.dart';
import '../ui/body_map.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';
import 'stall_sheet.dart';

/// REPORTS → BODY: what got trained in the window, what got skipped, and
/// which lifts stopped moving.
class BodyView extends StatefulWidget {
  const BodyView({super.key});
  @override
  State<BodyView> createState() => _BodyViewState();
}

class _BodyViewState extends State<BodyView> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    return Loader<Insights>(
      load: Insights.load,
      builder: (context, d) {
        final app = AppScope.of(context);
        final today = dateOnly(DateTime.now());
        // Nothing logged yet: a plain figure, not 19 red outlines.
        final empty = d.lastTrained.isEmpty;
        final untrained = empty
            ? <String>{}
            : {
                for (final m in Insights.mapped)
                  if ((d.sets[m] ?? 0) == 0) m,
              };
        Color colorOf(String m) => Heat.of(d.perWeek(m));
        void tap(String? m) =>
            setState(() => selected = m == selected ? null : m);
        final neglected = d.neglected;
        final stalls = d.stalls.values.toList()
          ..sort((a, b) => b.stall.weeks.compareTo(a.stall.weeks));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: KText(
                    '${d.windowDays} days',
                    size: 44,
                    wdth: 62,
                    wght: 900,
                  ),
                ),
                Text(
                  'SETS / WEEK\nPER MUSCLE',
                  style: label(),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final side in BodySide.values)
                  Expanded(
                    child: Column(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: BodyMap(
                            side: side,
                            female: app.profile.femaleFigure,
                            colorOf: colorOf,
                            selected: selected,
                            untrained: untrained,
                            onTap: tap,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Lbl(side == BodySide.front ? 'Front' : 'Back'),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const _Ramp(),
            const SizedBox(height: 12),
            if (empty)
              Text(
                'Finish a workout and the muscles you trained light up here. The ones you skip get a red outline.',
                style: mono(12, height: 1.5),
              )
            else ...[
              _info(app, d, today),
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Lbl('Neglected · last ${d.windowDays} days'),
                    const SizedBox(height: 6),
                    if (neglected.isEmpty)
                      Text(
                        'Every muscle got at least 5 sets a week. Nothing skipped.',
                        style: mono(12),
                      )
                    else
                      for (final m in neglected)
                        _MissRow(
                          muscle: m,
                          zero: (d.sets[m] ?? 0) == 0,
                          side: (d.sets[m] ?? 0) == 0
                              ? '0 sets · ${_ago(d.lastTrained[m], today)}'
                              : '${d.perWeek(m).toStringAsFixed(1)} sets/wk · low',
                          onTap: () => tap(m),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (app.profile.stallAlerts)
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Lbl(
                        'Stalled lifts · no est. 1RM gain in ${app.profile.stallWeeks}+ weeks',
                      ),
                      const SizedBox(height: 4),
                      KText(
                        '${stalls.length}',
                        size: 72,
                        wdth: 62,
                        wght: 900,
                        color: stalls.isEmpty ? Tone.good : Tone.danger,
                      ),
                      const SizedBox(height: 6),
                      if (stalls.isEmpty)
                        Text(
                          'Every lift you trained twice lately is still going up.',
                          style: mono(12),
                        )
                      else
                        for (final s in stalls)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _StallCard(info: s),
                          ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _info(AppState app, Insights d, DateTime today) {
    final m = selected;
    final trained = Insights.mapped.where((x) => (d.sets[x] ?? 0) > 0).length;
    final zero = m != null && (d.sets[m] ?? 0) == 0;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: zero ? Tone.danger : Heat.growth, width: 2),
        ),
      ),
      child: m == null
          ? Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Tap a muscle to see its sets and lifts.\n',
                  ),
                  TextSpan(
                    text: '$trained of ${Insights.mapped.length}',
                    style: mono(
                      11.5,
                      color: Tone.bone,
                      weight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: ' muscles trained in ${d.windowDays} days.'),
                ],
              ),
              style: mono(11.5, height: 1.45),
            )
          : Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: m.toUpperCase(),
                    style: mono(
                      11.5,
                      color: Tone.bone,
                      weight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' · ${_fmt(d.sets[m] ?? 0)} sets · ${d.perWeek(m).toStringAsFixed(1)}/wk · ${_ago(d.lastTrained[m], today)}\n',
                  ),
                  TextSpan(
                    text: (d.lifts[m] ?? const []).isEmpty
                        ? 'No lifts in this window.'
                        : d.lifts[m]!.take(4).join(', '),
                  ),
                ],
              ),
              style: mono(11.5, height: 1.45),
            ),
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _ago(DateTime? last, DateTime today) {
  if (last == null) return 'never trained';
  final n = daysBetween(last, today);
  return n == 0 ? 'last today' : 'last ${n}d ago';
}

class _Ramp extends StatelessWidget {
  const _Ramp();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('0', style: mono(9.5)),
      const SizedBox(width: 6),
      for (final c in const [Heat.low, Heat.some, Heat.growth, Heat.high])
        Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      const SizedBox(width: 6),
      Text('20+', style: mono(9.5)),
    ],
  );
}

class _MissRow extends StatelessWidget {
  const _MissRow({
    required this.muscle,
    required this.zero,
    required this.side,
    required this.onTap,
  });
  final String muscle, side;
  final bool zero;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Tone.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              muscle.toUpperCase(),
              style: display(
                20,
                wdth: 70,
                wght: zero ? 850 : 300,
                color: zero ? Tone.danger : Tone.bone,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(side, style: mono(10.5), textAlign: TextAlign.right),
          ),
        ],
      ),
    ),
  );
}

class _StallCard extends StatelessWidget {
  const _StallCard({required this.info});
  final StallInfo info;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      onTap: () => showStallSheet(context, info),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  info.exercise.name.toUpperCase(),
                  style: display(19, wdth: 72, wght: 850, height: 1),
                ),
              ),
              StallBadge(info),
            ],
          ),
          const SizedBox(height: 6),
          StallSpark(info),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text:
                      'Est. 1RM ${app.wWithUnit(info.stall.best)}, flat ${info.stall.weeks} weeks · ',
                ),
                TextSpan(
                  text: 'Tap for options',
                  style: mono(10.5, color: Tone.bone, weight: FontWeight.w500),
                ),
              ],
            ),
            style: mono(10.5),
          ),
        ],
      ),
    );
  }
}
