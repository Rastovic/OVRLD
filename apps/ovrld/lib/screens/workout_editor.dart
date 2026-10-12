import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/tokens.dart';
import 'exercise_picker.dart';
import 'today_screen.dart' show supersetLabels;

/// Returns the saved workout's id.
Future<int?> openWorkoutEditor(BuildContext context, Template? t) =>
    Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => WorkoutEditor(template: t)));

class WorkoutEditor extends StatefulWidget {
  const WorkoutEditor({super.key, this.template});
  final Template? template;
  @override
  State<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends State<WorkoutEditor> {
  late final name = TextEditingController(text: widget.template?.name ?? '');
  late int? splitId = widget.template?.splitId;
  late final items = [for (final i in widget.template?.items ?? const <TemplateItem>[]) i.copy()];

  /// linked[i]: item i is in a superset with item i + 1.
  late final linked = [
    for (var i = 0; i < items.length; i++)
      items[i].grp != null && i + 1 < items.length && items[i + 1].grp == items[i].grp,
  ];
  bool dirty = false;

  void _regroup() {
    var g = 0;
    for (var i = 0; i < items.length; i++) {
      final inGroup = linked[i] || (i > 0 && linked[i - 1]);
      if (!inGroup) {
        items[i].grp = null;
        continue;
      }
      if (i == 0 || !linked[i - 1]) g++;
      items[i].grp = g;
    }
  }

  /// Rebuilds [linked] from the items' groups after a structural change.
  void _relink() {
    linked
      ..clear()
      ..addAll([
        for (var i = 0; i < items.length; i++)
          items[i].grp != null && i + 1 < items.length && items[i + 1].grp == items[i].grp,
      ]);
  }

  Future<void> _add() async {
    final app = AppScope.read(context);
    final id = await pickExercise(context);
    if (id == null) return;
    setState(() {
      items.add(TemplateItem(exerciseId: id, sets: 3, repMin: app.profile.goal.repMin, repMax: app.profile.goal.repMax));
      linked.add(false);
      dirty = true;
    });
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    final n = name.text.trim();
    if (n.isEmpty) {
      toast(context, 'Give the workout a name.');
      return;
    }
    if (linked.isNotEmpty) linked[linked.length - 1] = false;
    _regroup();
    final t = Template(id: widget.template?.id, name: n, splitId: splitId, items: items);
    final id = await app.repo.saveTemplate(t);
    await app.changed();
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    _regroup();
    final labels = supersetLabels(items.map((i) => i.grp).toList());
    final color = app.splits[splitId]?.color ?? Tone.bone;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context, 'Discard changes?', 'Your edits to this workout are not saved.', yes: 'Discard');
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.template == null ? 'NEW WORKOUT' : 'EDIT WORKOUT'),
          actions: [
            if (widget.template != null)
              IconButton(
                tooltip: 'Delete workout',
                icon: const Icon(Icons.delete_outline, color: Tone.mute),
                onPressed: () async {
                  if (!await confirm(context, 'Delete workout', 'Past sessions keep their sets. Plan days using it become rest days.')) return;
                  await app.repo.archiveTemplate(widget.template!.id!);
                  await app.changed();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            TextButton(onPressed: _save, child: Text('SAVE', style: mono(13, color: Tone.bone, weight: FontWeight.w600))),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.sentences,
              style: display(26, wdth: 80, wght: 850),
              decoration: const InputDecoration(hintText: 'Name, e.g. Leg day'),
              onChanged: (_) => dirty = true,
            ),
            const SizedBox(height: 14),
            const Lbl('Split'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in app.splitList)
                ChoiceChip(
                  avatar: Dot(s.color, size: 10, radius: 5),
                  label: Text(s.name, style: mono(12, color: splitId == s.id ? onColor(s.color) : Tone.bone)),
                  selected: splitId == s.id,
                  showCheckmark: false,
                  selectedColor: s.color,
                  backgroundColor: Tone.raised,
                  side: const BorderSide(color: Tone.line),
                  onSelected: (_) => setState(() {
                    splitId = s.id;
                    dirty = true;
                  }),
                ),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Lbl('Exercises · ${items.length}')),
              Text('hold ≡ to reorder', style: mono(10)),
            ]),
            const SizedBox(height: 4),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: (a, b) => setState(() {
                // Each item keeps its group through the move; pairs that are
                // still next to each other stay a superset, the rest split.
                final it = items.removeAt(a);
                items.insert(b, it);
                _relink();
                dirty = true;
              }),
              itemBuilder: (c, i) => _ItemCard(
                key: ObjectKey(items[i]),
                index: i,
                item: items[i],
                label: labels[i],
                color: color,
                linked: linked[i],
                isLast: i == items.length - 1,
                onChanged: () => setState(() => dirty = true),
                onLink: () => setState(() {
                  linked[i] = !linked[i];
                  dirty = true;
                }),
                onRemove: () => setState(() {
                  items.removeAt(i);
                  _relink();
                  dirty = true;
                }),
              ),
            ),
            const SizedBox(height: 10),
            GhostButton('Add exercise', icon: Icons.add, onPressed: _add),
            const SizedBox(height: 20),
            BigButton('Save', color: color, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.label,
    required this.color,
    required this.linked,
    required this.isLast,
    required this.onChanged,
    required this.onLink,
    required this.onRemove,
  });
  final int index;
  final TemplateItem item;
  final String? label;
  final Color color;
  final bool linked, isLast;
  final VoidCallback onChanged, onLink, onRemove;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final e = app.exercises[item.exerciseId];
    final inGroup = label != null;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: Tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: inGroup ? color : Tone.line, width: inGroup ? 3 : 1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (label != null) Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(label!, style: mono(11, color: color, weight: FontWeight.w600)),
          ),
          Expanded(child: Text((e?.name ?? '?').toUpperCase(), style: display(17, wdth: 80, wght: 800))),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.close, size: 18, color: Tone.mute), tooltip: 'Remove'),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle, color: Tone.mute)),
          ),
        ]),
        Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _Mini('sets', item.sets, (v) {
            item.sets = v.clamp(1, 20);
            onChanged();
          }),
          if (e?.kind != ExerciseKind.time) ...[
            _Mini('min reps', item.repMin, (v) {
              item.repMin = v.clamp(1, item.repMax);
              onChanged();
            }),
            _Mini('max reps', item.repMax, (v) {
              item.repMax = v.clamp(item.repMin, 100);
              onChanged();
            }),
          ],
          _RestPicker(item: item, onChanged: onChanged),
        ]),
        if (!isLast)
          TextButton.icon(
            onPressed: onLink,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 34)),
            icon: Icon(linked ? Icons.link_off : Icons.link, size: 16, color: linked ? color : Tone.mute),
            label: Text(linked ? 'Unlink from next' : 'Superset with next', style: mono(11, color: linked ? color : Tone.mute)),
          ),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value, this.onSet);
  final String label;
  final int value;
  final ValueChanged<int> onSet;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: mono(10.5)),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onSet(value - 1),
          icon: const Icon(Icons.remove, size: 16, color: Tone.mute),
        ),
        Text('$value', style: mono(15, color: Tone.bone, weight: FontWeight.w600)),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onSet(value + 1),
          icon: const Icon(Icons.add, size: 16, color: Tone.mute),
        ),
      ]);
}

class _RestPicker extends StatelessWidget {
  const _RestPicker({required this.item, required this.onChanged});
  final TemplateItem item;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
        tooltip: 'Rest after each set',
        onSelected: (v) {
          item.restS = v < 0 ? null : v;
          onChanged();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: -1, child: Text('Default', style: mono(13, color: Tone.bone))),
          for (final s in [0, 45, 60, 90, 120, 150, 180, 240, 300])
            PopupMenuItem(value: s, child: Text(s == 0 ? 'No rest timer' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}', style: mono(13, color: Tone.bone))),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'rest ${item.restS == null ? 'default' : item.restS == 0 ? 'off' : '${item.restS! ~/ 60}:${(item.restS! % 60).toString().padLeft(2, '0')}'} · change',
            style: mono(10.5, color: Tone.bone),
          ),
        ),
      );
}
