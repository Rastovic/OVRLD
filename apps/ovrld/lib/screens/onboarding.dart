import 'package:flutter/material.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';

/// First run: who you are, which units, and whether to start from the
/// ready-made week or from nothing. Everything here can be changed later.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final name = TextEditingController();
  final weight = TextEditingController();
  final height = TextEditingController();
  WeightUnit wu = WeightUnit.kg;
  Goal goal = Goal.muscle;
  bool starter = true;
  bool busy = false;

  Future<void> go() async {
    setState(() => busy = true);
    final app = AppScope.read(context);
    final p = app.profile
      ..name = name.text.trim()
      ..weightUnit = wu
      ..distanceUnit = wu == WeightUnit.kg ? DistanceUnit.km : DistanceUnit.mi
      ..heightUnit = wu == WeightUnit.kg ? HeightUnit.cm : HeightUnit.ftIn
      ..goal = goal
      ..onboarded = true;
    final h = parseNum(height.text);
    if (h != null && h > 0) p.heightCm = wu == WeightUnit.kg ? h : h * 2.54;
    final bw = parseNum(weight.text);
    if (bw != null && bw > 0) await app.repo.addBodyWeight(DateTime.now(), displayToKg(bw, wu));
    if (starter) await app.repo.createStarterPlan();
    await app.repo.saveProfile(p);
    await app.changed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const _Title(),
            const SizedBox(height: 10),
            Text('Log kg × reps. Beat last time. Plan the week.', style: mono(13)),
            const SizedBox(height: 28),
            const Lbl('Your name'),
            const SizedBox(height: 6),
            TextField(controller: name, textCapitalization: TextCapitalization.words, style: mono(15, color: Tone.bone)),
            const SizedBox(height: 18),
            const Lbl('Units'),
            const SizedBox(height: 8),
            ChoiceRow<WeightUnit>(
              values: WeightUnit.values,
              selected: wu,
              labelOf: (u) => u == WeightUnit.kg ? 'kg · cm · km' : 'lb · in · mi',
              onChanged: (u) => setState(() => wu = u),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Lbl('Body weight'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: mono(15, color: Tone.bone),
                    decoration: InputDecoration(suffixText: weightLabel(wu)),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Lbl('Height'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: height,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: mono(15, color: Tone.bone),
                    decoration: InputDecoration(suffixText: wu == WeightUnit.kg ? 'cm' : 'in'),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            const Lbl('Main goal'),
            const SizedBox(height: 8),
            ChoiceRow<Goal>(
              values: Goal.values,
              selected: goal,
              labelOf: (g) => '${g.label} ${g.repMin}–${g.repMax}',
              onChanged: (g) => setState(() => goal = g),
            ),
            const SizedBox(height: 24),
            const Lbl('Start with'),
            const SizedBox(height: 8),
            _StartCard(
              selected: starter,
              title: 'Ready week',
              body: 'Mon legs · Tue push · Thu pull · Fri upper · Sat run. Edit anything.',
              onTap: () => setState(() => starter = true),
            ),
            const SizedBox(height: 8),
            _StartCard(
              selected: !starter,
              title: 'Empty',
              body: 'Build your own workouts and week from scratch.',
              onTap: () => setState(() => starter = false),
            ),
            const SizedBox(height: 28),
            BigButton(busy ? '...' : "Let's go", onPressed: busy ? null : go),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();
  @override
  Widget build(BuildContext context) {
    const letters = 'OVRLD';
    return SizedBox(
      height: 120,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(children: [
          for (var i = 0; i < letters.length; i++) _PulseLetter(letters[i], i),
        ]),
      ),
    );
  }
}

class _PulseLetter extends StatefulWidget {
  const _PulseLetter(this.ch, this.i);
  final String ch;
  final int i;
  @override
  State<_PulseLetter> createState() => _PulseLetterState();
}

class _PulseLetterState extends State<_PulseLetter> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.i * 90), () {
      if (mounted) c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (calm(context)) return Text(widget.ch, style: display(120, wdth: 100, wght: 800));
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(c.value);
        return Text(widget.ch, style: display(120, wdth: 62 + 63 * t, wght: 900 - 600 * t, height: .82));
      },
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.selected, required this.title, required this.body, required this.onTap});
  final bool selected;
  final String title, body;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Tone.bone : Tone.line, width: selected ? 1.5 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            VaryText(title, size: 26, wdth: selected ? 110 : 70, wght: selected ? 900 : 300,
                color: selected ? Tone.bone : Tone.mute),
            const SizedBox(height: 4),
            Text(body, style: mono(12)),
          ]),
        ),
      );
}
