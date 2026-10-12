import 'package:flutter/material.dart';

import '../data/models.dart';
import '../services/rest_alerts.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/tokens.dart';
import 'cardio_screen.dart';
import 'session_screen.dart';

/// Starts [t] (or an empty workout) with the clock at zero.
///
/// Only one workout can run at a time. One that is still open with nothing
/// logged is thrown away, so a new tap is always a fresh start. One with sets
/// in it is resumed when [resume] is set or it is the same workout; anything
/// else asks first rather than silently continuing an old clock.
Future<void> startWorkout(BuildContext context, {Template? t, bool offPlan = false, String? name, bool resume = false}) async {
  final app = AppScope.read(context);
  // Held before anything changes: saving a session rebuilds Today (the
  // in-progress card appears or goes), which can unmount the button that
  // called us. The navigator outlives that rebuild; [context] may not.
  final nav = Navigator.of(context);
  final open = app.openSession;
  if (open != null) {
    final full = await app.repo.fullSession(open.id);
    if (full.allSets.isEmpty) {
      await app.repo.deleteSession(open.id);
      await app.changed();
    } else {
      var go = resume || (t != null && open.templateId == t.id) ? 'resume' : null;
      if (go == null) {
        if (!nav.mounted) return;
        go = await _askAboutOpen(nav.context, full);
      }
      if (go == null) return;
      if (go == 'resume') {
        await nav.push(MaterialPageRoute(builder: (_) => SessionScreen(sessionId: open.id)));
        return;
      }
      await app.repo.deleteSession(open.id);
      await RestAlerts.instance.cancel();
      await app.changed();
    }
  }
  await RestAlerts.instance.askPermission();
  final id = await app.repo.startSession(t: t, offPlan: offPlan, name: name);
  await app.changed();
  if (!nav.mounted) return;
  await nav.push(MaterialPageRoute(builder: (_) => SessionScreen(sessionId: id)));
}

Future<String?> _askAboutOpen(BuildContext context, FullSession f) {
  final mins = DateTime.now().difference(f.session.startedAt).inMinutes;
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('${f.session.name.toUpperCase()} IS STILL RUNNING', style: display(22, wdth: 80)),
      content: Text(
        'Started $mins min ago, ${f.workingSets} sets logged. Carry on with it, or throw it away and start fresh?',
        style: mono(13, color: Tone.bone),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel', style: mono(13))),
        TextButton(
          onPressed: () => Navigator.pop(c, 'discard'),
          child: Text('Discard, start new', style: mono(13, color: Tone.danger)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, 'resume'),
          child: Text('Resume', style: mono(13, color: Tone.bone, weight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

Future<void> openCardio(BuildContext context, {Cardio? existing, CardioActivity? activity}) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CardioScreen(existing: existing, activity: activity),
    ));

/// "Train anyway" / "Not today?": any workout, an empty one, or cardio.
Future<void> pickAnyWorkout(BuildContext context, {required bool offPlan}) async {
  final app = AppScope.read(context);
  final choice = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Lbl('Start a workout'),
            const SizedBox(height: 8),
            for (final t in app.templates)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Dot(app.splits[t.splitId]?.color ?? Tone.bone, size: 14, radius: 4),
                title: Text(t.name, style: display(22, wdth: 80, wght: 800)),
                subtitle: Text('${t.items.length} exercises', style: mono(11)),
                onTap: () => Navigator.pop(c, t),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add, color: Tone.bone),
              title: Text('Empty workout', style: display(22, wdth: 80, wght: 800)),
              subtitle: Text('Add exercises as you go', style: mono(11)),
              onTap: () => Navigator.pop(c, 'empty'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.directions_run, color: app.cardioColor),
              title: Text('Cardio', style: display(22, wdth: 80, wght: 800)),
              subtitle: Text('Run, ride, row, swim', style: mono(11)),
              onTap: () => Navigator.pop(c, 'cardio'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'cardio') return openCardio(context);
  if (choice == 'empty') return startWorkout(context, offPlan: offPlan, name: 'Workout');
  if (choice is Template) return startWorkout(context, t: choice, offPlan: offPlan);
}
