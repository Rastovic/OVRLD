import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/models.dart';
import '../services/backup.dart';
import '../services/rest_alerts.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';
import 'exercise_picker.dart';
import 'tour.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.profile;
    Future<void> save() async {
      await app.repo.saveProfile(p);
      await app.changed();
    }

    final age = p.ageOn(DateTime.now());
    final height = p.heightCm == null
        ? '–'
        : p.heightUnit == HeightUnit.cm
            ? '${p.heightCm!.round()} cm'
            : () {
                final (ft, inch) = cmToFeetInches(p.heightCm!);
                return '$ft′ $inch″';
              }();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
        children: [
          GestureDetector(
            onTap: () async {
              final n = await askText(context, title: 'Your name', initial: p.name);
              if (n == null) return;
              p.name = n;
              await save();
            },
            child: KText(p.name.isEmpty ? 'You' : p.name, size: 64, wdth: 75, wght: 900),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _Big('Weight', app.bodyWeightKg == null ? '–' : app.w(app.bodyWeightKg!), unit: app.wLabel, onTap: () => _addWeight(context)),
            _Big('Height', height, onTap: () => _height(context)),
            _Big('Age', age == null ? '–' : '$age', onTap: () => _birth(context)),
          ]),
          const SizedBox(height: 8),
          if (app.bodyWeightKg != null && p.heightCm != null)
            Text(
              'BMI ${(app.bodyWeightKg! / ((p.heightCm! / 100) * (p.heightCm! / 100))).toStringAsFixed(1)} · tap a number to change it',
              style: mono(11),
            )
          else
            Text('Tap a number to change it.', style: mono(11)),
          const SizedBox(height: 20),
          _Section('Body weight log', children: [
            _WeightLog(),
            const SizedBox(height: 6),
            GhostButton('Add today', icon: Icons.add, onPressed: () => _addWeight(context)),
          ]),
          _Section('Training', children: [
            const Lbl('Main goal (sets default rep ranges)'),
            const SizedBox(height: 6),
            ChoiceRow<Goal>(values: Goal.values, selected: p.goal, labelOf: (g) => '${g.label} ${g.repMin}–${g.repMax}', onChanged: (g) {
              p.goal = g;
              save();
            }),
            const SizedBox(height: 14),
            const Lbl('Experience'),
            const SizedBox(height: 6),
            ChoiceRow<Experience>(values: Experience.values, selected: p.experience, labelOf: (e) => e.label, onChanged: (e) {
              p.experience = e;
              save();
            }),
            const SizedBox(height: 14),
            const Lbl('Default rest between sets'),
            const SizedBox(height: 6),
            ChoiceRow<int>(
              values: const [60, 90, 120, 150, 180],
              selected: p.restDefaultS,
              labelOf: (s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
              onChanged: (s) {
                p.restDefaultS = s;
                save();
              },
            ),
            const SizedBox(height: 4),
            const _ExactAlarmRow(),
            const SizedBox(height: 14),
            const Lbl('Sex (optional)'),
            const SizedBox(height: 6),
            ChoiceRow<Sex?>(values: const [null, ...Sex.values], selected: p.sex, labelOf: (s) => s?.label ?? 'Skip', onChanged: (s) {
              p.sex = s;
              save();
            }),
          ]),
          _Section('Units', children: [
            ChoiceRow<WeightUnit>(values: WeightUnit.values, selected: p.weightUnit, labelOf: weightLabel, onChanged: (u) {
              p.weightUnit = u;
              save();
            }),
            const SizedBox(height: 8),
            ChoiceRow<DistanceUnit>(values: DistanceUnit.values, selected: p.distanceUnit, labelOf: distanceLabel, onChanged: (u) {
              p.distanceUnit = u;
              save();
            }),
            const SizedBox(height: 8),
            ChoiceRow<HeightUnit>(values: HeightUnit.values, selected: p.heightUnit, labelOf: (u) => u == HeightUnit.cm ? 'cm' : 'ft / in', onChanged: (u) {
              p.heightUnit = u;
              save();
            }),
            const SizedBox(height: 6),
            Text('Everything is stored in metric. Switching only changes what you see.', style: mono(10.5)),
          ]),
          _Section('Split colours', children: [
            for (final s in app.splitList)
              InkWell(
                onTap: () => _editSplit(context, s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Dot(s.color, size: 18, radius: 9),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.name.toUpperCase(), style: display(18, wdth: 85, wght: 800, color: s.color))),
                    const Icon(Icons.edit_outlined, size: 16, color: Tone.mute),
                  ]),
                ),
              ),
            Wrap(spacing: 8, children: [
              GhostButton('New split', icon: Icons.add, onPressed: () => _newSplit(context)),
              GhostButton('Reset colours', onPressed: () async {
                await app.repo.resetSplitColors();
                await app.changed();
              }),
            ]),
          ]),
          _Section('Library', children: [
            InfoRow('Exercises', '${app.exercises.values.where((e) => !e.archived).length}', onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExercisePicker(manage: true)));
            }),
          ]),
          _Section('Backup', children: [
            Text('One file with everything: workouts, sets, plans, cardio, body weight. Save it to Drive or send it to yourself.', style: mono(11.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              GhostButton('Export', icon: Icons.ios_share, onPressed: () => Backup.export(app.repo)),
              GhostButton('Restore', icon: Icons.restore, onPressed: () => _restore(context)),
            ]),
          ]),
          _Section('About', children: [
            InfoRow('Show walkthrough', '', onTap: () => showTour(context)),
            InfoRow('Privacy policy', 'rastovic.github.io/ovrld/privacy', onTap: () async {
              await Clipboard.setData(const ClipboardData(text: 'https://rastovic.github.io/ovrld/privacy/'));
              if (context.mounted) toast(context, 'Link copied. Paste it in your browser.');
            }),
            InfoRow('Version', '0.1.3'),
            InfoRow('Licences', '', onTap: () => showLicensePage(context: context, applicationName: 'OVRLD', applicationVersion: '0.1.3')),
          ]),
        ],
      ),
    );
  }

  Future<void> _addWeight(BuildContext context) async {
    final app = AppScope.read(context);
    final v = await askNumber(context, title: 'Body weight today', unit: app.wLabel,
        initial: app.bodyWeightKg == null ? null : double.parse(app.w(app.bodyWeightKg!)));
    if (v == null || v <= 0) return;
    await app.repo.addBodyWeight(DateTime.now(), displayToKg(v, app.wu));
    await app.changed();
  }

  Future<void> _height(BuildContext context) async {
    final app = AppScope.read(context);
    final cm = app.profile.heightUnit == HeightUnit.cm;
    final v = await askNumber(context, title: 'Height', unit: cm ? 'cm' : 'in',
        initial: app.profile.heightCm == null ? null : (cm ? app.profile.heightCm!.roundToDouble() : (app.profile.heightCm! / 2.54).roundToDouble()));
    if (v == null || v <= 0) return;
    app.profile.heightCm = cm ? v : v * 2.54;
    await app.repo.saveProfile(app.profile);
    await app.changed();
  }

  Future<void> _birth(BuildContext context) async {
    final app = AppScope.read(context);
    final d = await showDatePicker(
      context: context,
      initialDate: app.profile.birthDate ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Date of birth',
    );
    if (d == null) return;
    app.profile.birthDate = d;
    await app.repo.saveProfile(app.profile);
    await app.changed();
  }

  Future<void> _editSplit(BuildContext context, SplitTag s) async {
    final app = AppScope.read(context);
    final name = TextEditingController(text: s.name);
    var color = s.color;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                KText(name.text.isEmpty ? 'Split' : name.text, size: 48, wdth: 90, wght: 900, color: color),
                const SizedBox(height: 10),
                TextField(controller: name, style: mono(15, color: Tone.bone), onChanged: (_) => set(() {})),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final c2 in SplitColors.palette)
                    GestureDetector(
                      onTap: () => set(() => color = c2),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c2,
                          shape: BoxShape.circle,
                          border: Border.all(color: color == c2 ? Tone.bone : Colors.transparent, width: 3),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 18),
                BigButton('Save', size: 22, color: color, onPressed: () => Navigator.pop(c, true)),
              ]),
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    s
      ..name = name.text.trim().isEmpty ? s.name : name.text.trim()
      ..color = color;
    await app.repo.updateSplit(s);
    await app.changed();
  }

  Future<void> _newSplit(BuildContext context) async {
    final app = AppScope.read(context);
    final n = await askText(context, title: 'New split', hint: 'e.g. Glutes, Back & biceps');
    if (n == null) return;
    final used = app.splitList.map((s) => s.color.toARGB32()).toSet();
    final color = SplitColors.palette.firstWhere((c) => !used.contains(c.toARGB32()), orElse: () => SplitColors.palette.first);
    await app.repo.addSplit(n, color.toARGB32());
    await app.changed();
  }

  Future<void> _restore(BuildContext context) async {
    final app = AppScope.read(context);
    if (!await confirm(context, 'Restore backup', 'Everything in the app now is replaced by the backup file.', yes: 'Choose file')) return;
    try {
      final done = await Backup.import(app.repo);
      if (!done) return;
      await app.changed();
      if (context.mounted) toast(context, 'Backup restored.');
    } on FormatException catch (e) {
      if (context.mounted) toast(context, e.message);
    } catch (e) {
      if (context.mounted) toast(context, 'Could not restore: $e');
    }
  }
}

/// Shows whether the rest buzz can fire on the second with the screen off,
/// and opens the system switch when it cannot.
class _ExactAlarmRow extends StatefulWidget {
  const _ExactAlarmRow();
  @override
  State<_ExactAlarmRow> createState() => _ExactAlarmRowState();
}

class _ExactAlarmRowState extends State<_ExactAlarmRow> with WidgetsBindingObserver {
  bool? allowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final a = await RestAlerts.instance.exactAllowed();
    if (mounted) setState(() => allowed = a);
  }

  @override
  Widget build(BuildContext context) => InfoRow(
        'Rest buzz on time',
        allowed == null ? '' : allowed! ? 'On' : 'Off · tap to allow',
        onTap: allowed == false ? RestAlerts.instance.askExact : null,
      );
}

class _Big extends StatelessWidget {
  const _Big(this.label, this.value, {this.unit, this.onTap});
  final String label, value;
  final String? unit;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Lbl(label),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: value, style: display(38, wdth: 75, wght: 850)),
                if (unit != null) TextSpan(text: ' $unit', style: mono(11)),
              ])),
            ),
          ]),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: display(20, wdth: 80, wght: 800)),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );
}

class _WeightLog extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Loader<List<BodyWeight>>(
        load: (app) => app.repo.bodyWeights(),
        builder: (context, list) {
          final app = AppScope.of(context);
          if (list.isEmpty) return Text('No entries yet.', style: mono(12));
          return Column(children: [
            for (final b in list.reversed.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(child: Text(shortDate(b.date), style: mono(12))),
                  Text('${app.w(b.kg)} ${app.wLabel}', style: mono(13, color: Tone.bone)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete entry',
                    icon: const Icon(Icons.close, size: 16, color: Tone.mute),
                    onPressed: () async {
                      await app.repo.deleteBodyWeight(b.id);
                      await app.changed();
                    },
                  ),
                ]),
              ),
            if (list.length > 6) Text('${list.length - 6} older entries in the Reports trend.', style: mono(10.5)),
          ]);
        },
      );
}
