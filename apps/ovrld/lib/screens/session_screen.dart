import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/models.dart';
import '../data/repo.dart';
import '../services/rest_alerts.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';
import 'exercise_picker.dart';
import 'finish_screen.dart';
import 'today_screen.dart' show supersetLabels;

/// The logger. The number is the screen.
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.sessionId});
  final int sessionId;
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> with WidgetsBindingObserver {
  FullSession? f;
  final last = <int, LastTime?>{}; // by exercise
  final bests = <int, Bests>{}; // by exercise, grows during the session
  int cursor = 0; // index into f.items
  double kg = 0;
  int reps = 8;
  int seconds = 30;
  bool warmup = false;
  Timer? ticker;
  DateTime? restEnds;
  int restTotal = 0;

  AppState get app => AppScope.read(context);

  /// For the stateless parts of this screen that change the dials.
  void update(VoidCallback fn) => setState(fn);
  List<SessionItem> get items => f!.items;
  SessionItem? get item => items.isEmpty ? null : items[cursor.clamp(0, items.length - 1)];
  Exercise? get ex => item == null ? null : app.exercises[item!.exerciseId];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(first: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final end = restEnds;
    if (end != null && DateTime.now().isAfter(end)) {
      restEnds = null;
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 180), HapticFeedback.heavyImpact);
      RestAlerts.instance.cancel();
    }
    setState(() {});
  }

  Future<void> _load({bool first = false}) async {
    final full = await app.repo.fullSession(widget.sessionId);
    for (final i in full.items) {
      if (!last.containsKey(i.exerciseId)) {
        final l = await app.repo.lastTime(i.exerciseId, excludeSession: widget.sessionId);
        last[i.exerciseId] = l;
        final b = Bests.from(l?.allHistory ?? const []);
        // Sets already logged in this session count, after a resume too.
        for (final s in full.items.where((x) => x.exerciseId == i.exerciseId).expand((x) => x.sets)) {
          b.add(s.result);
        }
        bests[i.exerciseId] = b;
      }
    }
    if (!mounted) return;
    setState(() {
      f = full;
      if (first) cursor = _firstUnfinished();
      cursor = cursor.clamp(0, full.items.isEmpty ? 0 : full.items.length - 1);
    });
    _prefill();
  }

  int _firstUnfinished() {
    for (var i = 0; i < items.length; i++) {
      if (items[i].sets.where((s) => !s.warmup).length < items[i].setsPlanned) return i;
    }
    return 0;
  }

  /// The block (single exercise or superset) that item [i] belongs to.
  List<int> _block(int i) {
    final g = items[i].grp;
    if (g == null) return [i];
    var a = i, b = i;
    while (a > 0 && items[a - 1].grp == g) {
      a--;
    }
    while (b + 1 < items.length && items[b + 1].grp == g) {
      b++;
    }
    return [for (var k = a; k <= b; k++) k];
  }

  int _done(SessionItem i) => i.sets.where((s) => !s.warmup).length;

  void _prefill() {
    final it = item, e = ex;
    if (it == null || e == null) return;
    final mine = it.sets;
    if (mine.isNotEmpty) {
      final s = mine.last;
      kg = s.kg;
      reps = s.reps;
      seconds = s.seconds ?? seconds;
      warmup = false;
    } else {
      final l = last[e.id];
      final target = l == null
          ? null
          : nextTarget(
              last: [for (final s in l.sets) s.result],
              repMin: it.repMin,
              repMax: it.repMax,
              incrementKg: e.incrementKg,
              plannedSets: l.setsPlanned,
            );
      if (target != null) {
        kg = target.kg;
        reps = target.reps;
      } else {
        kg = switch (e.kind) {
          ExerciseKind.weightReps => e.equipment == 'Barbell' ? 20 : 10,
          _ => 0,
        };
        reps = it.repMin;
      }
      final lastSecs = l?.working.lastOrNull?.seconds;
      if (lastSecs != null) seconds = lastSecs + 5;
      warmup = false;
    }
    setState(() {});
  }

  void _go(int i) {
    setState(() => cursor = i);
    _prefill();
  }

  Future<void> _log() async {
    final it = item, e = ex;
    if (it == null || e == null) return;
    final idx = it.sets.length;
    final isTime = e.kind == ExerciseKind.time;
    await app.repo.addSet(
      it.id,
      idx: idx,
      kg: e.usesWeight ? kg : 0,
      reps: isTime ? 1 : reps,
      seconds: isTime ? seconds : null,
      warmup: warmup,
    );
    bests[e.id]?.add(SetResult(e.usesWeight ? kg : 0, isTime ? 1 : reps, warmup: warmup));
    HapticFeedback.mediumImpact();
    final was = cursor;
    await _load();
    if (warmup) {
      setState(() => warmup = false);
      return;
    }

    // Superset: move to the next exercise in the block that still has sets
    // to do. Rest only once the round is complete.
    final block = _block(was);
    final pos = block.indexOf(was);
    int? nextInBlock;
    for (var k = 1; k <= block.length; k++) {
      final cand = block[(pos + k) % block.length];
      if (_done(items[cand]) < items[cand].setsPlanned) {
        nextInBlock = cand;
        break;
      }
    }
    final roundOver = nextInBlock == null || block.indexOf(nextInBlock) <= pos;
    if (nextInBlock != null) {
      _go(nextInBlock);
    } else {
      // Block finished: move on to the next unfinished exercise.
      final after = block.last + 1;
      if (after < items.length) _go(after);
    }
    if (roundOver) {
      final rest = it.restS ?? app.profile.restDefaultS;
      if (rest > 0 && _firstUnfinishedOrNull() != null) _startRest(rest);
    }
  }

  int? _firstUnfinishedOrNull() {
    for (var i = 0; i < items.length; i++) {
      if (_done(items[i]) < items[i].setsPlanned) return i;
    }
    return null;
  }

  void _startRest(int s) {
    restTotal = s;
    restEnds = DateTime.now().add(Duration(seconds: s));
    RestAlerts.instance.start(restEnds!, ex?.name ?? 'next set');
    setState(() {});
  }

  void _addRest(int s) {
    if (restEnds == null) return;
    restEnds = restEnds!.add(Duration(seconds: s));
    restTotal += s;
    RestAlerts.instance.start(restEnds!, ex?.name ?? 'next set');
    setState(() {});
  }

  void _skipRest() {
    restEnds = null;
    RestAlerts.instance.cancel();
    setState(() {});
  }

  Future<void> _addExercise() async {
    final id = await pickExercise(context);
    if (id == null) return;
    await app.repo.addItem(widget.sessionId, id, repMin: app.profile.goal.repMin, repMax: app.profile.goal.repMax);
    last.remove(id);
    await _load();
    _go(items.length - 1);
  }

  Future<void> _finish() async {
    final full = f!;
    if (full.workingSets == 0) {
      final discard = await confirm(context, 'Nothing logged', 'No sets were logged. Discard this workout?', yes: 'Discard');
      if (!discard) return;
      await app.repo.deleteSession(widget.sessionId);
      await RestAlerts.instance.cancel();
      await app.changed();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await RestAlerts.instance.cancel();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => FinishScreen(sessionId: widget.sessionId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final full = f;
    if (full == null) return const Scaffold();
    final color = app.colorOfSession(full.session);
    final elapsed = formatClock(DateTime.now().difference(full.session.startedAt).inSeconds);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Leaving with nothing logged: the workout never happened. Without
        // this the clock keeps running and the next tap "resumes" it.
        if (didPop && (f?.allSets.isEmpty ?? false)) {
          final app = this.app;
          app.repo.deleteSession(widget.sessionId).then((_) => app.changed());
          RestAlerts.instance.cancel();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(children: [
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 18, 0),
                child: Row(children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Tone.mute),
                    tooltip: 'Minimise - the session keeps running',
                  ),
                  Expanded(child: Text('${full.session.name.toUpperCase()} · $elapsed', style: mono(11), overflow: TextOverflow.ellipsis)),
                  if (items.isNotEmpty) Text('EX ${cursor + 1} / ${items.length}', style: mono(11)),
                ]),
              ),
              Expanded(
                child: items.isEmpty
                    ? _Empty(onAdd: _addExercise)
                    : _Logger(state: this, color: color),
              ),
              _BottomBar(
                onList: () => _openList(color),
                onFinish: _finish,
              ),
            ]),
            if (restEnds != null) _RestOverlay(state: this, color: color),
          ]),
        ),
      ),
    );
  }

  Future<void> _openList(Color color) async {
    final labels = supersetLabels(items.map((i) => i.grp).toList());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Lbl('Exercises'),
              const SizedBox(height: 6),
              for (var i = 0; i < items.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: i == cursor,
                  leading: SizedBox(
                    width: 28,
                    child: Text(labels[i] ?? '${i + 1}', style: mono(12, color: labels[i] != null ? color : Tone.mute, weight: FontWeight.w600)),
                  ),
                  title: Text(
                    (app.exercises[items[i].exerciseId]?.name ?? '?').toUpperCase(),
                    style: display(17, wdth: 80, wght: i == cursor ? 850 : 600, color: i == cursor ? Tone.bone : Tone.bone.withValues(alpha: .8)),
                  ),
                  subtitle: Text('${_done(items[i])} / ${items[i].setsPlanned} sets', style: mono(11)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_done(items[i]) >= items[i].setsPlanned) const Icon(Icons.check, color: Tone.good, size: 18),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Tone.mute, size: 20),
                      onSelected: (v) async {
                        Navigator.pop(c);
                        if (v == 'remove') {
                          final ok = items[i].sets.isEmpty ||
                              await confirm(context, 'Remove exercise', 'Its logged sets in this workout are deleted too.', yes: 'Remove');
                          if (!ok) return;
                          await app.repo.removeItem(items[i].id);
                          await _load();
                          _prefill();
                        } else if (v == 'more') {
                          items[i].setsPlanned++;
                          await app.repo.updateItem(items[i]);
                          await _load();
                        } else if (v == 'less' && items[i].setsPlanned > 1) {
                          items[i].setsPlanned--;
                          await app.repo.updateItem(items[i]);
                          await _load();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'more', child: Text('One more set', style: mono(13, color: Tone.bone))),
                        PopupMenuItem(value: 'less', child: Text('One set fewer', style: mono(13, color: Tone.bone))),
                        PopupMenuItem(value: 'remove', child: Text('Remove', style: mono(13, color: Tone.danger))),
                      ],
                    ),
                  ]),
                  onTap: () {
                    Navigator.pop(c);
                    _go(i);
                  },
                ),
              const SizedBox(height: 8),
              GhostButton('Add exercise', icon: Icons.add, onPressed: () {
                Navigator.pop(c);
                _addExercise();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editSet(SetEntry s) async {
    final e = ex!;
    final isTime = e.kind == ExerciseKind.time;
    var k = s.kg, r = s.reps, sec = s.seconds ?? 0;
    var wu = s.warmup;
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Lbl('Set ${s.idx + 1}'),
              const SizedBox(height: 12),
              if (e.usesWeight)
                _Dial(
                  label: 'Weight',
                  value: app.w(k),
                  unit: app.wLabel,
                  size: 56,
                  minus: () => set(() => k = (k - _stepKg(e)).clamp(0, 2000)),
                  plus: () => set(() => k = k + _stepKg(e)),
                  minusText: '−${formatNumber(displayStep(e.incrementKg, app.wu))}',
                  plusText: '+${formatNumber(displayStep(e.incrementKg, app.wu))}',
                ),
              if (isTime)
                _Dial(label: 'Seconds', value: '$sec', unit: 's', size: 56,
                    minus: () => set(() => sec = (sec - 5).clamp(0, 3600)), plus: () => set(() => sec += 5),
                    minusText: '−5', plusText: '+5')
              else
                _Dial(label: 'Reps', value: '$r', unit: 'reps', size: 56,
                    minus: () => set(() => r = (r - 1).clamp(1, 999)), plus: () => set(() => r++),
                    minusText: '−1', plusText: '+1'),
              const SizedBox(height: 8),
              FilterChip(
                label: Text('Warm-up', style: mono(12, color: wu ? Tone.ground : Tone.bone)),
                selected: wu,
                showCheckmark: false,
                selectedColor: Tone.bone,
                onSelected: (v) => set(() => wu = v),
              ),
              const SizedBox(height: 14),
              Row(children: [
                TextButton(onPressed: () => Navigator.pop(c, 'delete'), child: Text('Delete set', style: mono(13, color: Tone.danger))),
                const Spacer(),
                FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: Text('Save', style: mono(13, color: Tone.ground, weight: FontWeight.w600))),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (result == 'delete') {
      await app.repo.deleteSet(s.id);
    } else if (result == 'save') {
      s
        ..kg = k
        ..reps = isTime ? 1 : r
        ..seconds = isTime ? sec : null
        ..warmup = wu;
      await app.repo.updateSet(s);
    } else {
      return;
    }
    // Rebuild the bests from history plus what remains in this session.
    bests.remove(e.id);
    last.remove(e.id);
    await _load();
  }

  double _stepKg(Exercise e) => displayToKg(displayStep(e.incrementKg <= 0 ? 2.5 : e.incrementKg, app.wu), app.wu);
}

class _Logger extends StatelessWidget {
  const _Logger({required this.state, required this.color});
  final _SessionScreenState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = state;
    final it = s.item!, e = s.ex;
    if (e == null) return const SizedBox.shrink();
    final block = s._block(s.cursor);
    final labels = supersetLabels(s.items.map((i) => i.grp).toList());
    final l = s.last[e.id];
    final isTime = e.kind == ExerciseKind.time;
    final b = s.bests[e.id];
    final pr = (s.warmup || isTime || b == null)
        ? const <PrKind>{}
        : b.wouldBeat(SetResult(e.usesWeight ? s.kg : 0, s.reps));
    final step = displayStep(e.incrementKg <= 0 ? 2.5 : e.incrementKg, app.wu);
    final stepKg = displayToKg(step, app.wu);
    final working = it.sets.where((x) => !x.warmup).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      children: [
        if (block.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${block.length == 2 ? 'SUPERSET' : 'CIRCUIT'} ${labels[s.cursor]} · with ${block.where((k) => k != s.cursor).map((k) => app.exercises[s.items[k].exerciseId]?.name ?? '').join(', ')}',
              style: mono(11, color: color, weight: FontWeight.w500),
            ),
          ),
        Text(
          e.name.toUpperCase(),
          style: display(40, wdth: 70, wght: 850, height: .92),
          maxLines: 2,
        ),
        const SizedBox(height: 10),
        _SetBars(done: working, planned: it.setsPlanned, color: color),
        const SizedBox(height: 14),
        if (e.usesWeight) ...[
          Row(children: [
            Lbl(e.kind == ExerciseKind.bodyweight ? 'Added weight' : 'Weight'),
            const SizedBox(width: 8),
            Stamp(text: pr.isEmpty ? 'PR' : _prShort(pr), visible: pr.isNotEmpty),
          ]),
          LayoutBuilder(
            builder: (context, c) => RollingNumber(app.w(s.kg), size: (c.maxWidth * .34).clamp(64, 132)),
          ),
          Row(children: [
            Expanded(
              child: Text(
                '${app.wLabel}${l != null && l.working.isNotEmpty ? ' · last ${app.w(l.working.map((x) => x.kg).reduce((a, b) => a > b ? a : b))}' : ''}',
                style: mono(12),
              ),
            ),
            StepButton('−${formatNumber(step)}', semantic: 'Minus ${formatNumber(step)} ${app.wLabel}',
                onStep: () => s.update(() => s.kg = (s.kg - stepKg).clamp(0, 2000).toDouble())),
            const SizedBox(width: 8),
            StepButton('+${formatNumber(step)}', semantic: 'Plus ${formatNumber(step)} ${app.wLabel}',
                onStep: () => s.update(() => s.kg = s.kg + stepKg)),
          ]),
          const SizedBox(height: 14),
        ],
        if (isTime) ...[
          const Lbl('Seconds'),
          LayoutBuilder(builder: (context, c) => RollingNumber('${s.seconds}', size: (c.maxWidth * .34).clamp(64, 132))),
          Row(children: [
            Expanded(child: Text('seconds', style: mono(12))),
            StepButton('−5', semantic: 'Five seconds less', onStep: () => s.update(() => s.seconds = (s.seconds - 5).clamp(5, 3600))),
            const SizedBox(width: 8),
            StepButton('+5', semantic: 'Five seconds more', onStep: () => s.update(() => s.seconds += 5)),
          ]),
        ] else ...[
          const Lbl('Reps'),
          LayoutBuilder(builder: (context, c) => RollingNumber('${s.reps}', size: (c.maxWidth * .22).clamp(48, 84))),
          Row(children: [
            Expanded(child: Text('target ${it.repMin}–${it.repMax}', style: mono(12))),
            StepButton('−1', semantic: 'One rep less', onStep: () => s.update(() => s.reps = (s.reps - 1).clamp(1, 999))),
            const SizedBox(width: 8),
            StepButton('+1', semantic: 'One rep more', onStep: () => s.update(() => s.reps++)),
          ]),
        ],
        const SizedBox(height: 14),
        _Hint(app: app, e: e, it: it, last: l, color: color, reps: s.reps),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: Text('Warm-up set', style: mono(12, color: s.warmup ? Tone.ground : Tone.bone)),
            selected: s.warmup,
            showCheckmark: false,
            selectedColor: Tone.bone,
            backgroundColor: Tone.raised,
            side: const BorderSide(color: Tone.line),
            onSelected: (v) => s.update(() => s.warmup = v),
          ),
        ),
        const SizedBox(height: 12),
        BigButton(
          s.warmup ? 'Log warm-up' : 'Log set ${working + 1}',
          color: Tone.bone,
          onPressed: s._log,
        ),
        if (it.sets.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Lbl('Logged'),
          const SizedBox(height: 4),
          for (final x in it.sets)
            InkWell(
              onTap: () => s._editSet(x),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  SizedBox(width: 30, child: Text(x.warmup ? 'W' : '${it.sets.where((y) => !y.warmup && y.idx <= x.idx).length}', style: mono(12))),
                  Expanded(
                    child: Text(
                      isTime
                          ? '${x.seconds ?? 0} s'
                          : e.usesWeight
                              ? '${e.kind == ExerciseKind.bodyweight ? 'BW + ' : ''}${app.w(x.kg)} ${app.wLabel} × ${x.reps}'
                              : '${x.reps} reps',
                      style: mono(14, color: x.warmup ? Tone.mute : Tone.bone),
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 16, color: Tone.mute),
                ]),
              ),
            ),
        ],
      ],
    );
  }
}

String _prShort(Set<PrKind> k) =>
    k.contains(PrKind.heaviest) ? 'PR' : k.contains(PrKind.e1rm) ? 'PR · 1RM' : 'PR · REPS';

class _Hint extends StatelessWidget {
  const _Hint({required this.app, required this.e, required this.it, required this.last, required this.color, required this.reps});
  final AppState app;
  final Exercise e;
  final SessionItem it;
  final LastTime? last;
  final Color color;
  final int reps;

  @override
  Widget build(BuildContext context) {
    final l = last;
    InlineSpan body;
    if (l == null || l.working.isEmpty) {
      body = TextSpan(text: e.kind == ExerciseKind.time
          ? 'First time. Hold as long as good form allows.'
          : 'First time. Pick a weight you can do for ${it.repMin}–${it.repMax} clean reps.');
    } else if (e.kind == ExerciseKind.time) {
      body = TextSpan(text: 'Last time: ${l.working.map((s) => '${s.seconds ?? 0}s').join(' · ')}. Add five seconds.');
    } else {
      final t = nextTarget(
        last: [for (final s in l.sets) s.result],
        repMin: it.repMin,
        repMax: it.repMax,
        incrementKg: e.incrementKg,
        plannedSets: l.setsPlanned,
      );
      final lastText = e.usesWeight
          ? l.working.map((s) => '${app.w(s.kg)}×${s.reps}').join(' · ')
          : l.working.map((s) => '${s.reps}').join(' · ');
      final bold = mono(11, color: Tone.bone, weight: FontWeight.w600);
      body = TextSpan(children: [
        TextSpan(text: 'Last: $lastText.\n'),
        if (t != null && t.increase && e.usesWeight) ...[
          const TextSpan(text: 'Every set hit the top of the range. Today: '),
          TextSpan(text: '${app.w(t.kg)} ${app.wLabel}', style: bold),
          const TextSpan(text: '.'),
        ] else if (t != null) ...[
          const TextSpan(text: 'Same weight, beat the reps: aim for '),
          TextSpan(text: '${t.reps}', style: bold),
          TextSpan(text: ' on every set, then ${e.usesWeight ? 'add weight' : 'make it harder'}.'),
        ],
      ]);
    }
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 2))),
      child: Text.rich(body, style: mono(11, height: 1.5)),
    );
  }
}

class _SetBars extends StatelessWidget {
  const _SetBars({required this.done, required this.planned, required this.color});
  final int done, planned;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final n = done > planned ? done + 1 : planned;
    return Semantics(
      label: 'Set ${done + 1} of $planned',
      child: Row(children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              decoration: BoxDecoration(
                color: i < done ? color : i == done ? Tone.bone : Tone.raised,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({required this.label, required this.value, required this.unit, required this.size, required this.minus, required this.plus, required this.minusText, required this.plusText});
  final String label, value, unit, minusText, plusText;
  final double size;
  final VoidCallback minus, plus;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Lbl(label),
        RollingNumber(value, size: size),
        Row(children: [
          Expanded(child: Text(unit, style: mono(12))),
          StepButton(minusText, semantic: 'Less', onStep: minus),
          const SizedBox(width: 8),
          StepButton(plusText, semantic: 'More', onStep: plus),
        ]),
        const SizedBox(height: 10),
      ]);
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onList, required this.onFinish});
  final VoidCallback onList, onFinish;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tone.line))),
        child: Row(children: [
          Flexible(child: GhostButton('Exercises', icon: Icons.list, onPressed: onList)),
          const SizedBox(width: 10),
          const Spacer(),
          FilledButton(
            onPressed: onFinish,
            style: FilledButton.styleFrom(backgroundColor: Tone.bone, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            child: FittedBox(child: Text('FINISH', style: display(18, wdth: 110, wght: 900, color: Tone.ground))),
          ),
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.center, children: [
          const KText('Empty', size: 100, wdth: 62, wght: 200),
          const SizedBox(height: 10),
          Text('Add the first exercise and start logging.', style: mono(13)),
          const SizedBox(height: 20),
          BigButton('Add exercise', onPressed: onAdd),
        ]),
      );
}

class _RestOverlay extends StatelessWidget {
  const _RestOverlay({required this.state, required this.color});
  final _SessionScreenState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final left = s.restEnds!.difference(DateTime.now()).inSeconds + 1;
    final frac = s.restTotal == 0 ? 0.0 : (left / s.restTotal).clamp(0.0, 1.0);
    final next = s.ex;
    return Positioned.fill(
      child: Material(
        color: Tone.ground.withValues(alpha: .97),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Lbl('Rest'),
            const Spacer(),
            LayoutBuilder(
              builder: (context, c) => RollingNumber(formatClock(left.clamp(0, 36000)), size: c.maxWidth * .38, wdth: 62),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: frac, minHeight: 6, color: color, backgroundColor: Tone.raised),
            ),
            const SizedBox(height: 16),
            if (next != null) ...[
              const Lbl('Up next'),
              const SizedBox(height: 4),
              Text(next.name.toUpperCase(), style: display(28, wdth: 75, wght: 850)),
              Text(
                next.usesWeight ? '${s.app.w(s.kg)} ${s.app.wLabel} × ${s.reps}' : next.kind == ExerciseKind.time ? '${s.seconds} s' : '${s.reps} reps',
                style: mono(13),
              ),
            ],
            const Spacer(),
            Row(children: [
              Expanded(child: GhostButton('+15 s', onPressed: () => s._addRest(15))),
              const SizedBox(width: 10),
              Expanded(child: GhostButton('−15 s', onPressed: () => s._addRest(-15))),
            ]),
            const SizedBox(height: 10),
            BigButton('Skip rest', color: color, onPressed: s._skipRest),
          ]),
        ),
      ),
    );
  }
}
