import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// A bordered card. Used by role, not by default: reports and settings
/// sections, never around the big type.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Tone.ground,
        border: Border.all(color: Tone.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: box),
    );
  }
}

class Lbl extends StatelessWidget {
  const Lbl(this.text, {super.key, this.color = Tone.mute});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: label(color: color));
}

/// The big wide-to-narrow button: START, LOG SET, SAVE.
class BigButton extends StatefulWidget {
  const BigButton(this.text, {super.key, required this.onPressed, this.color = Tone.bone, this.size = 26});
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  @override
  State<BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<BigButton> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final bg = enabled ? widget.color : Tone.raised;
    return Semantics(
      button: true,
      label: widget.text,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => down = true) : null,
        onTapCancel: () => setState(() => down = false),
        onTapUp: enabled ? (_) => setState(() => down = false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.mediumImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: down ? 62 : 125),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            builder: (context, w, _) => FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.text.toUpperCase(),
                maxLines: 1,
                style: display(widget.size, wdth: w, wght: 900, color: enabled ? onColor(bg) : Tone.mute),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton(this.text, {super.key, required this.onPressed, this.icon});
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? null : Icon(icon, size: 16),
        label: Text(text, style: mono(12, color: Tone.bone), overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: Tone.bone,
          side: const BorderSide(color: Tone.line),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 40),
        ),
      );
}

/// Square step button on the logger: −2.5 / +2.5, −1 / +1. Hold to repeat.
class StepButton extends StatefulWidget {
  const StepButton(this.text, {super.key, required this.onStep, required this.semantic});
  final String text;
  final String semantic;
  final VoidCallback onStep;
  @override
  State<StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<StepButton> {
  bool held = false;

  Future<void> repeat() async {
    await Future.delayed(const Duration(milliseconds: 380));
    while (held && mounted) {
      widget.onStep();
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 110));
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.semantic,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onStep();
          },
          onLongPressStart: (_) {
            held = true;
            repeat();
          },
          onLongPressEnd: (_) => held = false,
          child: Container(
            width: 58,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Tone.raised,
              border: Border.all(color: Tone.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(widget.text, style: mono(14, color: Tone.bone, weight: FontWeight.w500)),
          ),
        ),
      );
}

/// Choice chips in the mono label style.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({super.key, required this.values, required this.selected, required this.labelOf, required this.onChanged});
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in values)
            ChoiceChip(
              label: Text(labelOf(v), style: mono(12, color: v == selected ? Tone.ground : Tone.bone)),
              selected: v == selected,
              showCheckmark: false,
              selectedColor: Tone.bone,
              backgroundColor: Tone.raised,
              side: const BorderSide(color: Tone.line),
              shape: const StadiumBorder(),
              onSelected: (_) => onChanged(v),
            ),
        ],
      );
}

class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 10, this.radius = 3});
  final Color? color;
  final double size;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color ?? Tone.raised, borderRadius: BorderRadius.circular(radius)),
      );
}

/// A settings-style row: label left, value right, chevron when tappable.
class InfoRow extends StatelessWidget {
  const InfoRow(this.title, this.value, {super.key, this.onTap});
  final String title;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(title, style: mono(13, color: Tone.bone))),
              Flexible(
                child: Text(value, style: mono(13), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 18, color: Tone.mute),
              ],
            ],
          ),
        ),
      );
}

Future<bool> confirm(BuildContext context, String title, String body, {String yes = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: display(24, wdth: 80)),
      content: Text(body, style: mono(13, color: Tone.bone)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: mono(13, color: Tone.mute))),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(yes, style: mono(13, color: Tone.danger, weight: FontWeight.w600))),
      ],
    ),
  );
  return r ?? false;
}

/// One-field number prompt, used for body weight, height, durations.
Future<double?> askNumber(
  BuildContext context, {
  required String title,
  String? unit,
  double? initial,
  bool decimal = true,
}) async {
  final ctl = TextEditingController(text: initial == null ? '' : _trim(initial));
  final r = await showDialog<double>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: display(22, wdth: 80)),
      content: TextField(
        controller: ctl,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        style: mono(18, color: Tone.bone),
        decoration: InputDecoration(suffixText: unit),
        onSubmitted: (_) => Navigator.pop(c, parseNum(ctl.text)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel', style: mono(13))),
        TextButton(
          onPressed: () => Navigator.pop(c, parseNum(ctl.text)),
          child: Text('Save', style: mono(13, color: Tone.bone, weight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return r;
}

Future<String?> askText(BuildContext context, {required String title, String initial = '', String? hint}) async {
  final ctl = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: display(22, wdth: 80)),
      content: TextField(
        controller: ctl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: mono(15, color: Tone.bone),
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(c, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel', style: mono(13))),
        TextButton(
          onPressed: () => Navigator.pop(c, ctl.text.trim()),
          child: Text('Save', style: mono(13, color: Tone.bone, weight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return (r == null || r.isEmpty) ? null : r;
}

/// Accepts "102,5" as well as "102.5" - a European keyboard gives a comma.
double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

String _trim(double v) {
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}
