import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/seed.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/tokens.dart';

Future<int?> pickExercise(BuildContext context) =>
    Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => const ExercisePicker()));

class ExercisePicker extends StatefulWidget {
  const ExercisePicker({super.key, this.manage = false});

  /// Library mode (from Profile): tap edits instead of picking.
  final bool manage;
  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  String q = '';
  String? muscle;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final all = app.exercises.values
        .where((e) => widget.manage || !e.archived)
        .where((e) => muscle == null || e.muscle == muscle)
        .where((e) => q.isEmpty || e.name.toLowerCase().contains(q.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: Text(widget.manage ? 'EXERCISES' : 'ADD EXERCISE')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Tone.bone,
        foregroundColor: Tone.ground,
        onPressed: () async {
          final id = await editExercise(context, null, initialName: q);
          if (id != null && context.mounted && !widget.manage) Navigator.pop(context, id);
        },
        icon: const Icon(Icons.add),
        label: Text('NEW', style: mono(13, color: Tone.ground, weight: FontWeight.w600)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            autofocus: !widget.manage,
            style: mono(15, color: Tone.bone),
            decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search, color: Tone.mute)),
            onChanged: (v) => setState(() => q = v.trim()),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final m in [null, ...muscles])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(m ?? 'All', style: mono(12, color: muscle == m ? Tone.ground : Tone.bone)),
                    selected: muscle == m,
                    showCheckmark: false,
                    selectedColor: Tone.bone,
                    backgroundColor: Tone.raised,
                    side: const BorderSide(color: Tone.line),
                    onSelected: (_) => setState(() => muscle = m),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
            itemCount: all.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (c, i) {
              final e = all[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.name.toUpperCase(),
                    style: display(17, wdth: 80, wght: 750, color: e.archived ? Tone.mute : Tone.bone)),
                subtitle: Text(
                  '${e.muscle} · ${e.equipment}${e.archived ? ' · hidden' : ''}${e.custom ? ' · yours' : ''}',
                  style: mono(11),
                ),
                trailing: widget.manage ? const Icon(Icons.edit_outlined, size: 18, color: Tone.mute) : null,
                onTap: () async {
                  if (widget.manage) {
                    await editExercise(context, e);
                  } else {
                    Navigator.pop(context, e.id);
                  }
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Create (when [e] is null) or edit an exercise. Returns its id.
Future<int?> editExercise(BuildContext context, Exercise? e, {String initialName = ''}) async {
  final app = AppScope.read(context);
  final name = TextEditingController(text: e?.name ?? initialName);
  var muscle = e?.muscle ?? 'Chest';
  var equipment = e?.equipment ?? 'Barbell';
  var kind = e?.kind ?? ExerciseKind.weightReps;
  var inc = e?.incrementKg ?? defaultIncrement(equipment);
  var archived = e?.archived ?? false;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Lbl(e == null ? 'New exercise' : 'Edit exercise'),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                autofocus: e == null,
                textCapitalization: TextCapitalization.sentences,
                style: mono(15, color: Tone.bone),
                decoration: const InputDecoration(hintText: 'Name'),
              ),
              const SizedBox(height: 14),
              const Lbl('Muscle'),
              const SizedBox(height: 6),
              ChoiceRow<String>(values: muscles, selected: muscle, labelOf: (m) => m, onChanged: (m) => set(() => muscle = m)),
              const SizedBox(height: 14),
              const Lbl('Equipment'),
              const SizedBox(height: 6),
              ChoiceRow<String>(
                values: equipments,
                selected: equipment,
                labelOf: (m) => m,
                onChanged: (m) => set(() {
                  equipment = m;
                  inc = defaultIncrement(m);
                }),
              ),
              const SizedBox(height: 14),
              const Lbl('Logged as'),
              const SizedBox(height: 6),
              ChoiceRow<ExerciseKind>(
                values: ExerciseKind.values,
                selected: kind,
                labelOf: (k) => switch (k) {
                  ExerciseKind.weightReps => 'Weight × reps',
                  ExerciseKind.bodyweight => 'Body + added kg',
                  ExerciseKind.reps => 'Reps only',
                  ExerciseKind.time => 'Time',
                },
                onChanged: (k) => set(() => kind = k),
              ),
              if (kind == ExerciseKind.weightReps || kind == ExerciseKind.bodyweight) ...[
                const SizedBox(height: 14),
                const Lbl('Weight step (kg)'),
                const SizedBox(height: 6),
                ChoiceRow<double>(
                  values: const [1, 1.25, 2, 2.5, 4, 5, 10],
                  selected: inc,
                  labelOf: (v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v',
                  onChanged: (v) => set(() => inc = v),
                ),
              ],
              if (e != null) ...[
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Hide from pickers', style: mono(13, color: Tone.bone)),
                  subtitle: Text('History is kept', style: mono(11)),
                  value: archived,
                  onChanged: (v) => set(() => archived = v),
                ),
              ],
              const SizedBox(height: 16),
              BigButton('Save', size: 22, onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(c, true);
              }),
            ]),
          ),
        ),
      ),
    ),
  );
  if (saved != true) return null;
  final n = name.text.trim();
  final step = (kind == ExerciseKind.reps || kind == ExerciseKind.time) ? 0.0 : inc;
  int id;
  if (e == null) {
    id = await app.repo.addExercise(name: n, muscle: muscle, equipment: equipment, kind: kind, incrementKg: step);
  } else {
    e
      ..name = n
      ..muscle = muscle
      ..equipment = equipment
      ..kind = kind
      ..incrementKg = step
      ..archived = archived;
    await app.repo.updateExercise(e);
    id = e.id;
  }
  await app.changed();
  return id;
}
