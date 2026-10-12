import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';
import 'finish_screen.dart' show WordRating, energyWords;

/// Log a run, ride, row or swim. Type time and distance afterwards, or run
/// the stopwatch. Pace is always worked out, never typed.
class CardioScreen extends StatefulWidget {
  const CardioScreen({super.key, this.existing, this.activity});
  final Cardio? existing;
  final CardioActivity? activity;
  @override
  State<CardioScreen> createState() => _CardioScreenState();
}

class _CardioScreenState extends State<CardioScreen> {
  late CardioActivity activity = widget.existing?.activity ?? widget.activity ?? CardioActivity.run;
  late DateTime when = widget.existing?.startedAt ?? DateTime.now();
  final h = TextEditingController();
  final m = TextEditingController();
  final s = TextEditingController();
  final dist = TextEditingController();
  final hr = TextEditingController();
  final note = TextEditingController();
  int? energy;
  DateTime? swStart;
  int swBase = 0;
  Timer? ticker;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _setDuration(e.durationS);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final app = AppScope.read(context);
        if (e.distanceM > 0) {
          dist.text = formatNumber(
            activity.pace.metres ? e.distanceM : metresToDisplay(e.distanceM, app.du),
            maxDecimals: 2,
          );
        }
        setState(() {});
      });
      hr.text = e.avgHr?.toString() ?? '';
      note.text = e.note ?? '';
      energy = e.energy;
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  void _setDuration(int total) {
    h.text = total >= 3600 ? '${total ~/ 3600}' : '';
    m.text = '${(total % 3600) ~/ 60}';
    s.text = (total % 60).toString().padLeft(2, '0');
  }

  int get duration {
    final hh = int.tryParse(h.text.trim()) ?? 0;
    final mm = int.tryParse(m.text.trim()) ?? 0;
    final ss = int.tryParse(s.text.trim()) ?? 0;
    return hh * 3600 + mm * 60 + ss;
  }

  /// Metres, from the distance field in the user's unit (metres for swim/row).
  double metres(AppState app) {
    final v = parseNum(dist.text) ?? 0;
    return activity.pace.metres ? v : displayToMetres(v, app.du);
  }

  void _toggleStopwatch() {
    HapticFeedback.mediumImpact();
    if (swStart == null) {
      swBase = duration;
      swStart = DateTime.now();
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _setDuration(swBase + DateTime.now().difference(swStart!).inSeconds);
        setState(() {});
      });
    } else {
      ticker?.cancel();
      _setDuration(swBase + DateTime.now().difference(swStart!).inSeconds);
      swStart = null;
    }
    setState(() {});
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    if (duration <= 0) {
      toast(context, 'Add how long it took.');
      return;
    }
    ticker?.cancel();
    final c = widget.existing ?? Cardio(activity: activity, startedAt: when, durationS: 0, distanceM: 0);
    c
      ..activity = activity
      ..startedAt = when
      ..durationS = duration
      ..distanceM = metres(app)
      ..avgHr = int.tryParse(hr.text.trim())
      ..energy = energy
      ..note = note.text.trim().isEmpty ? null : note.text.trim();
    await app.repo.saveCardio(c);
    await app.changed();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final color = app.cardioColor;
    final metresNow = metres(app);
    final (big, unit) = switch (activity.pace) {
      PaceMode.perDistance => (
          paceSeconds(duration, metresNow, app.du).let(formatClock) ?? '–:––',
          '/${app.dLabel}'
        ),
      PaceMode.per100m => (pacePer100m(duration, metresNow).let(formatClock) ?? '–:––', '/100 m'),
      PaceMode.per500m => (pacePer100m(duration, metresNow).let((p) => formatClock(p * 5)) ?? '–:––', '/500 m'),
      PaceMode.speed => (
          speed(duration, metresNow, app.du).let((v) => v.toStringAsFixed(1)) ?? '–',
          app.du == DistanceUnit.km ? 'km/h' : 'mph'
        ),
    };
    final distUnit = activity.pace.metres ? 'm' : app.dLabel;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'CARDIO' : 'EDIT CARDIO'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Tone.mute),
              onPressed: () async {
                if (!await confirm(context, 'Delete', 'Delete this ${activity.label.toLowerCase()}?')) return;
                await app.repo.deleteCardio(widget.existing!.id!);
                await app.changed();
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
        children: [
          ChoiceRow<CardioActivity>(
            values: CardioActivity.values,
            selected: activity,
            labelOf: (a) => a.label,
            onChanged: (a) => setState(() => activity = a),
          ),
          const SizedBox(height: 18),
          Lbl(activity.pace == PaceMode.speed ? 'Average speed' : 'Average pace', color: color),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(child: RollingNumber(big, size: 84, color: color, wdth: 70)),
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(unit, style: mono(13))),
          ]),
          const SizedBox(height: 14),
          const Lbl('Time'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _num(h, 'h')),
            const SizedBox(width: 8),
            Expanded(child: _num(m, 'min')),
            const SizedBox(width: 8),
            Expanded(child: _num(s, 's')),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: swStart == null ? Tone.raised : color),
              tooltip: swStart == null ? 'Start stopwatch' : 'Stop stopwatch',
              onPressed: _toggleStopwatch,
              icon: Icon(swStart == null ? Icons.play_arrow : Icons.stop, color: swStart == null ? Tone.bone : onColor(color)),
            ),
          ]),
          const SizedBox(height: 14),
          Lbl('Distance ($distUnit)'),
          const SizedBox(height: 6),
          _num(dist, distUnit, decimal: !activity.pace.metres),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Lbl('Avg heart rate'),
                const SizedBox(height: 6),
                _num(hr, 'bpm'),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Lbl('When'),
                const SizedBox(height: 6),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: Tone.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: when,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => when = DateTime(d.year, d.month, d.day, when.hour, when.minute));
                  },
                  child: Text(shortDate(when), style: mono(13, color: Tone.bone)),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          const Lbl('Energy'),
          WordRating(words: energyWords, value: energy, onChanged: (v) => setState(() => energy = v)),
          const SizedBox(height: 14),
          TextField(
            controller: note,
            textCapitalization: TextCapitalization.sentences,
            style: mono(14, color: Tone.bone),
            decoration: const InputDecoration(hintText: 'Note (optional): route, weather, shoes'),
          ),
          const SizedBox(height: 22),
          BigButton('Save', color: color, onPressed: _save),
        ],
      ),
    );
  }

  Widget _num(TextEditingController c, String suffix, {bool decimal = false}) => TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        style: mono(16, color: Tone.bone),
        textAlign: TextAlign.center,
        decoration: InputDecoration(suffixText: suffix, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14)),
        onChanged: (_) => setState(() {}),
      );
}

extension _Let<T extends Object> on T? {
  R? let<R>(R Function(T) f) => this == null ? null : f(this as T);
}

/// Pace or speed text for lists: "5:19 /km", "28.4 km/h", "2:05 /100 m".
String paceText(AppState app, Cardio c) => switch (c.activity.pace) {
      PaceMode.perDistance => paceSeconds(c.durationS, c.distanceM, app.du) == null
          ? ''
          : '${formatClock(paceSeconds(c.durationS, c.distanceM, app.du)!)} /${app.dLabel}',
      PaceMode.per100m => pacePer100m(c.durationS, c.distanceM) == null
          ? ''
          : '${formatClock(pacePer100m(c.durationS, c.distanceM)!)} /100 m',
      PaceMode.per500m => pacePer100m(c.durationS, c.distanceM) == null
          ? ''
          : '${formatClock(pacePer100m(c.durationS, c.distanceM)! * 5)} /500 m',
      PaceMode.speed => speed(c.durationS, c.distanceM, app.du) == null
          ? ''
          : '${speed(c.durationS, c.distanceM, app.du)!.toStringAsFixed(1)} ${app.du == DistanceUnit.km ? 'km/h' : 'mph'}',
    };

String distanceText(AppState app, Cardio c) => c.distanceM <= 0
    ? ''
    : c.activity.pace.metres
        ? '${c.distanceM.round()} m'
        : '${formatNumber(metresToDisplay(c.distanceM, app.du), maxDecimals: 2)} ${app.dLabel}';
