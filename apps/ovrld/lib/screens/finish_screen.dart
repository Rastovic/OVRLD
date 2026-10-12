import 'package:flutter/material.dart';
import 'package:ovrld_core/ovrld_core.dart';

import '../data/analytics.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';

const energyWords = ['Empty', 'Low', 'Okay', 'Strong', 'Beast'];
const feelWords = ['Rough', 'Meh', 'Fine', 'Good', 'Great'];

class FinishScreen extends StatefulWidget {
  const FinishScreen({super.key, required this.sessionId});
  final int sessionId;
  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  FullSession? f;
  int prs = 0;
  int? energy;
  int? feel;
  final note = TextEditingController();
  late final DateTime endedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = AppScope.read(context);
      final full = await app.repo.fullSession(widget.sessionId);
      final p = await prsInSession(app.repo, full);
      if (mounted) {
        setState(() {
          f = full;
          prs = p.length;
        });
      }
    });
  }

  Future<void> save() async {
    final app = AppScope.read(context);
    await app.repo.finishSession(
      widget.sessionId,
      energy: energy,
      feel: feel,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      endedAt: endedAt,
    );
    await app.changed();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final full = f;
    return Scaffold(
      body: SafeArea(
        child: full == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Row(children: [
                    Expanded(child: Text(shortDate(full.session.startedAt), style: mono(11))),
                    Text(full.session.name.toUpperCase(), style: mono(11, color: app.colorOfSession(full.session))),
                  ]),
                  const SizedBox(height: 12),
                  const VaryText('Done.', size: 120, wdth: 125, wght: 900, fromWdth: 62, fromWght: 200, duration: Duration(milliseconds: 900)),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.4,
                    children: [
                      _Stat('Time', formatClock(endedAt.difference(full.session.startedAt).inSeconds)),
                      _Stat('Volume', formatThousands(kgToDisplay(app.sessionVolume(full), app.wu)), unit: app.wLabel),
                      _Stat('Sets', '${full.workingSets}'),
                      _Stat('PRs', '$prs', color: prs > 0 ? Tone.pr : Tone.bone),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Lbl('Energy'),
                  const SizedBox(height: 6),
                  WordRating(words: energyWords, value: energy, onChanged: (v) => setState(() => energy = v)),
                  const SizedBox(height: 18),
                  const Lbl('How did it feel'),
                  const SizedBox(height: 8),
                  NumberRating(value: feel, words: feelWords, onChanged: (v) => setState(() => feel = v)),
                  const SizedBox(height: 18),
                  TextField(
                    controller: note,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: mono(14, color: Tone.bone),
                    decoration: const InputDecoration(hintText: 'Note (optional): slept badly, new shoes, knee ok'),
                  ),
                  const SizedBox(height: 22),
                  BigButton('Save', color: app.colorOfSession(full.session), onPressed: save),
                ],
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.unit, this.color = Tone.bone});
  final String label, value;
  final String? unit;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Lbl(label),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: value, style: display(34, wdth: 75, wght: 800, color: color)),
            if (unit != null) TextSpan(text: ' $unit', style: mono(12)),
          ])),
        ),
      ]);
}

/// The energy words: the picked one swells to full width, the rest stay thin.
class WordRating extends StatelessWidget {
  const WordRating({super.key, required this.words, required this.value, required this.onChanged});
  final List<String> words;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < words.length; i++)
            Semantics(
              button: true,
              selected: value == i + 1,
              label: words[i],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i + 1),
                child: SizedBox(
                  width: double.infinity,
                  child: VaryText(
                    words[i],
                    size: 38,
                    wdth: value == i + 1 ? 125 : 62,
                    wght: value == i + 1 ? 900 : 200,
                    color: value == i + 1 ? Tone.bone : SplitColors.rest,
                  ),
                ),
              ),
            ),
        ],
      );
}

class NumberRating extends StatelessWidget {
  const NumberRating({super.key, required this.value, required this.words, required this.onChanged});
  final int? value;
  final List<String> words;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 1; i <= 5; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == i,
                label: '$i, ${words[i - 1]}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Center(
                    child: VaryText(
                      '$i',
                      size: 48,
                      wdth: value == i ? 125 : 62,
                      wght: value == i ? 900 : 200,
                      color: value == i ? Tone.bone : SplitColors.rest,
                    ),
                  ),
                ),
              ),
            ),
        ]),
        if (value != null) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(words[value! - 1], style: mono(12, color: Tone.bone)),
        ),
      ]);
}
