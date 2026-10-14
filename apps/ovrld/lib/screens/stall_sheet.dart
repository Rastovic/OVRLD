import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/insights.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/tokens.dart';
import 'exercise_picker.dart';

/// The red STALL · 4W tag. Tappable wherever it appears.
class StallBadge extends StatelessWidget {
  const StallBadge(this.info, {super.key, this.onTap});
  final StallInfo info;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Tone.danger, borderRadius: BorderRadius.circular(4)),
      child: Text('STALL · ${info.stall.weeks}W',
          style: mono(10, color: Tone.ground, weight: FontWeight.w600, letterSpacing: 1, height: 1.3)),
    );
    if (onTap == null) return tag;
    return Semantics(
      button: true,
      label: '${info.exercise.name} stalled for ${info.stall.weeks} weeks. Options',
      child: GestureDetector(onTap: onTap, child: tag),
    );
  }
}

/// Best e1RM per session; the flat stretch since the unbeaten best in red.
class StallSpark extends StatelessWidget {
  const StallSpark(this.info, {super.key, this.height = 28});
  final StallInfo info;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SparkPainter(info)),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.info);
  final StallInfo info;

  @override
  void paint(Canvas canvas, Size size) {
    final h = info.history.length > 12 ? info.history.sublist(info.history.length - 12) : info.history;
    if (h.length < 2) return;
    final vs = h.map((p) => p.$2);
    final lo = vs.reduce(math.min) - 1, hi = vs.reduce(math.max) + 1;
    double x(int i) => 4 + i * (size.width - 8) / (h.length - 1);
    double y(double v) => size.height - 3 - (v - lo) / (hi - lo) * (size.height - 6);
    var flat = h.indexWhere((p) => !p.$1.isBefore(info.stall.since));
    if (flat < 0) flat = 0;
    canvas.drawRRect(
      RRect.fromLTRBR(x(flat) - 2, 0, size.width, size.height, const Radius.circular(3)),
      Paint()..color = Tone.danger.withValues(alpha: .12),
    );
    Path line(int a, int b) {
      final p = Path()..moveTo(x(a), y(h[a].$2));
      for (var i = a + 1; i <= b; i++) {
        p.lineTo(x(i), y(h[i].$2));
      }
      return p;
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    if (flat > 0) canvas.drawPath(line(0, flat), stroke..color = Tone.mute..strokeWidth = 1.5);
    canvas.drawPath(line(flat, h.length - 1), stroke..color = Tone.danger..strokeWidth = 2);
    canvas.drawCircle(Offset(x(h.length - 1), y(h.last.$2)), 2.8, Paint()..color = Tone.danger);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.info != info;
}

enum StallAction { deload, reps, swap, keep }

/// Rep range to move to: heavy goes to moderate, moderate to light, light
/// back to heavy. A different stimulus is the point, not the exact numbers.
(int, int) nextRepRange(int repMax) => repMax <= 8
    ? (10, 12)
    : repMax <= 12
        ? (12, 15)
        : (6, 8);

double deloadKg(StallInfo s) {
  final step = s.exercise.incrementKg > 0 ? s.exercise.incrementKg : 2.5;
  return (s.lastTopKg * .9 / step).round() * step;
}

/// The four ways out of a stall. Nothing changes until one is picked.
/// [item] is the exercise in a running workout, so a new rep range applies
/// there too. Returns what was done.
Future<StallAction?> showStallSheet(BuildContext context, StallInfo s, {SessionItem? item}) async {
  final app = AppScope.read(context);
  final e = s.exercise;
  final inPlan = app.templates.expand((t) => t.items).where((i) => i.exerciseId == e.id).firstOrNull;
  final repMin = item?.repMin ?? inPlan?.repMin ?? app.profile.goal.repMin;
  final repMax = item?.repMax ?? inPlan?.repMax ?? app.profile.goal.repMax;
  final (newMin, newMax) = nextRepRange(repMax);
  final deload = deloadKg(s);

  final action = await showModalBottomSheet<StallAction>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StallBadge(s),
          const SizedBox(height: 8),
          Text(e.name.toUpperCase(), style: display(34, wdth: 70, wght: 850, height: .92)),
          const SizedBox(height: 6),
          Text(
            'Est. 1RM ${app.wWithUnit(s.stall.best)}, not beaten for ${s.stall.weeks} weeks. Pick one way out. OVRLD only suggests.',
            style: mono(11.5, height: 1.5),
          ),
          const SizedBox(height: 10),
          StallSpark(s),
          const SizedBox(height: 14),
          _Option('Deload 10%', '${app.wWithUnit(deload)} × $repMax next time, then build back up', () => Navigator.pop(c, StallAction.deload)),
          _Option('Change reps', 'Move from $repMin–$repMax to $newMin–$newMax in every workout', () => Navigator.pop(c, StallAction.reps)),
          _Option('Swap exercise', 'Pick another ${e.muscle.toLowerCase()} lift for the same slot', () => Navigator.pop(c, StallAction.swap)),
          _Option('Keep going', 'Hide the badge for 2 weeks', () => Navigator.pop(c, StallAction.keep)),
        ]),
      ),
    ),
  );
  if (action == null || !context.mounted) return null;

  final now = DateTime.now();
  switch (action) {
    case StallAction.deload:
      e
        ..deloadKg = deload
        ..stallResetAt = now;
      await app.repo.updateExercise(e);
    case StallAction.reps:
      await app.repo.setRepRange(e.id, newMin, newMax);
      if (item != null) {
        item
          ..repMin = newMin
          ..repMax = newMax;
        await app.repo.updateItem(item);
      }
      e.stallResetAt = now;
      await app.repo.updateExercise(e);
    case StallAction.swap:
      final to = await pickExercise(context, group: groupOf(e.muscle));
      if (to == null || to == e.id || !context.mounted) return null;
      await app.repo.swapExercise(e.id, to);
      if (context.mounted) toast(context, 'From the next workout: ${app.exercises[to]?.name} replaces ${e.name}');
    case StallAction.keep:
      e.stallSnoozeUntil = now.add(const Duration(days: 14));
      await app.repo.updateExercise(e);
  }
  await app.changed();
  return action;
}

class _Option extends StatelessWidget {
  const _Option(this.title, this.body, this.onTap);
  final String title, body;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: display(17, wdth: 80, wght: 750, height: 1.1)),
            const SizedBox(height: 2),
            Text(body, style: mono(11)),
          ]),
        ),
      );
}
