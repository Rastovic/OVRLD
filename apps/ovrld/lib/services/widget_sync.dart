import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/models.dart';
import '../state/app_state.dart';

/// Publishes the whole active week to the home-screen widgets. The widget
/// picks today's entry itself, so it turns over at midnight without the app
/// being opened.
abstract final class WidgetSync {
  static const small = 'com.rastovic.ovrld.TodayWidgetSmall';
  static const wide = 'com.rastovic.ovrld.TodayWidgetWide';

  static Future<void> push(AppState app) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final plan = app.activePlan;
      for (var i = 0; i < 7; i++) {
        final d = plan?.days[i];
        final t = app.templateFor(d);
        final kind = d?.kind ?? DayKind.rest;
        String sub;
        final lines = <String>[];
        switch (kind) {
          case DayKind.workout:
            final n = t?.items.length ?? 0;
            sub = '$n ex · ~${_estimateMin(t)} min';
            for (final it in (t?.items ?? const <TemplateItem>[]).take(4)) {
              final e = app.exercises[it.exerciseId];
              if (e == null) continue;
              final last = await app.repo.lastTime(e.id);
              final target = last == null
                  ? null
                  : nextTarget(
                      last: [for (final s in last.sets) s.result],
                      repMin: it.repMin,
                      repMax: it.repMax,
                      incrementKg: e.incrementKg,
                      plannedSets: last.setsPlanned,
                    );
              final load = (target != null && e.usesWeight && target.kg > 0) ? ' · ${app.wWithUnit(target.kg)}' : '';
              lines.add('${e.name}|${it.sets} × ${it.repMin}–${it.repMax}$load');
            }
          case DayKind.cardio:
            sub = d?.note?.isNotEmpty == true ? d!.note! : 'Cardio';
          case DayKind.rest:
            sub = 'Recover';
        }
        await HomeWidget.saveWidgetData<String>('d${i}_kind', kind.name);
        await HomeWidget.saveWidgetData<String>('d${i}_word', app.dayWord(d).toUpperCase());
        await HomeWidget.saveWidgetData<String>('d${i}_title', app.dayTitle(d).toUpperCase());
        await HomeWidget.saveWidgetData<int>('d${i}_color', app.dayColor(d).toARGB32());
        await HomeWidget.saveWidgetData<String>('d${i}_sub', sub);
        await HomeWidget.saveWidgetData<String>('d${i}_lines', lines.join('\n'));
      }
      final today = dateOnly(DateTime.now());
      final done = await app.repo.sessionsBetween(today, addDays(today, 1));
      final cardio = await app.repo.cardio(from: today, to: addDays(today, 1));
      await HomeWidget.saveWidgetData<String>(
          'done_day', done.isNotEmpty || cardio.isNotEmpty ? dayKey(today) : '');
      await HomeWidget.saveWidgetData<bool>('has_plan', plan != null);
      await HomeWidget.updateWidget(qualifiedAndroidName: small);
      await HomeWidget.updateWidget(qualifiedAndroidName: wide);
    } catch (e) {
      debugPrint('widget sync failed: $e');
    }
  }

  /// Rough session length: 2.5 min per set including rest, plus 5 to warm up.
  static int _estimateMin(Template? t) {
    if (t == null) return 0;
    final sets = t.items.fold<int>(0, (a, i) => a + i.sets);
    return (sets * 2.5 + 5).round();
  }
}
