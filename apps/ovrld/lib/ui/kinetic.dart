import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// True when the system asks for reduced motion. Every kinetic widget below
/// then renders its resting state, which is always the real layout.
bool calm(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Display text that never overflows: it is scaled down to the width it is
/// given, so a wide setting on a narrow phone shrinks instead of clipping.
class KText extends StatelessWidget {
  const KText(
    this.text, {
    super.key,
    required this.size,
    this.wdth = 100,
    this.wght = 800,
    this.color = Tone.bone,
    this.upper = true,
    this.height = .9,
    this.align = Alignment.centerLeft,
    this.outline = false,
  });

  final String text;
  final double size;
  final double wdth;
  final double wght;
  final Color color;
  final bool upper;
  final double height;
  final Alignment align;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    var style = display(size, wdth: wdth, wght: wght, color: color, height: height);
    if (outline) {
      style = style.copyWith(
        color: null,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color,
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: align,
      child: Text(upper ? text.toUpperCase() : text, style: style, maxLines: 1),
    );
  }
}

/// Text whose width and weight animate from one setting to another whenever
/// they change - the rating words swelling, the week words growing in.
class VaryText extends StatelessWidget {
  const VaryText(
    this.text, {
    super.key,
    required this.size,
    required this.wdth,
    required this.wght,
    this.color = Tone.bone,
    this.fromWdth,
    this.fromWght,
    this.duration = const Duration(milliseconds: 420),
    this.delay = Duration.zero,
    this.height = .95,
  });

  final String text;
  final double size, wdth, wght;
  final double? fromWdth, fromWght;
  final Color color;
  final Duration duration, delay;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (calm(context)) {
      return KText(text, size: size, wdth: wdth, wght: wght, color: color, height: height);
    }
    return _Delayed(
      delay: delay,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(
          begin: Offset(fromWdth ?? wdth, fromWght ?? wght),
          end: Offset(wdth, wght),
        ),
        duration: duration,
        curve: Curves.easeOutBack,
        builder: (context, v, _) => TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: color),
          duration: duration,
          builder: (context, c, _) => KText(
            text,
            size: size,
            wdth: v.dx,
            wght: v.dy,
            color: c ?? color,
            height: height,
          ),
        ),
      ),
    );
  }
}

class _Delayed extends StatefulWidget {
  const _Delayed({required this.delay, required this.child});
  final Duration delay;
  final Widget child;
  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  bool go = false;
  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      go = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => go = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      go ? widget.child : Opacity(opacity: 0, child: widget.child);
}

/// The split name crawling across the top of Today, solid and outlined in
/// turn, in the split's colour.
class Marquee extends StatefulWidget {
  const Marquee(this.text, {super.key, required this.color, this.size = 92});
  final String text;
  final Color color;
  final double size;
  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Widget word(bool outline) => Padding(
        padding: EdgeInsets.only(right: widget.size * .24),
        child: Text(
          widget.text.toUpperCase(),
          maxLines: 1,
          softWrap: false,
          style: outline
              ? display(widget.size, wdth: 62, wght: 900, height: .88).copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.6
                    ..color = widget.color,
                )
              : display(widget.size, wdth: 62, wght: 900, color: widget.color, height: .88),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final style = display(widget.size, wdth: 62, wght: 900, height: .88);
    final tp = TextPainter(
      text: TextSpan(text: widget.text.toUpperCase(), style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final unit = (tp.width + widget.size * .24) * 2; // one solid + one outline
    final pair = [word(false), word(true)];
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [...pair, ...pair, ...pair, ...pair],
    );
    final h = tp.height;
    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: SizedBox(
          height: h,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: calm(context)
                  ? row
                  : AnimatedBuilder(
                      animation: c,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(-c.value * unit, 0),
                        child: child,
                      ),
                      child: row,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// REST, breathing slowly between narrow-hairline and wide-light.
class Breathe extends StatefulWidget {
  const Breathe(this.text, {super.key, required this.size, this.color = Tone.bone});
  final String text;
  final double size;
  final Color color;
  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (calm(context)) {
      return KText(widget.text, size: widget.size, wdth: 90, wght: 150, color: widget.color, height: .8);
    }
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(c.value);
        return KText(
          widget.text,
          size: widget.size,
          wdth: 62 + 63 * t,
          wght: 100 + 100 * t,
          color: widget.color,
          height: .8,
        );
      },
    );
  }
}

/// The logger's number: the old value squeezes narrow and rolls out upward,
/// the new one rolls in from below starting wide and settling.
class RollingNumber extends StatelessWidget {
  const RollingNumber(
    this.value, {
    super.key,
    required this.size,
    this.color = Tone.bone,
    this.wdth = 72,
  });

  final String value;
  final double size;
  final Color color;
  final double wdth;

  @override
  Widget build(BuildContext context) {
    final still = calm(context);
    return SizedBox(
      height: size * .98,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, anim) {
            final incoming = child.key == ValueKey(value);
            final slide = Tween<Offset>(
              begin: Offset(0, incoming ? .7 : -.7),
              end: Offset.zero,
            ).animate(anim);
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: anim, child: child),
            );
          },
          child: _NumberFace(
            key: ValueKey(value),
            value: value,
            size: size,
            color: color,
            wdth: wdth,
            animate: !still,
          ),
        ),
      ),
    );
  }
}

class _NumberFace extends StatelessWidget {
  const _NumberFace({
    super.key,
    required this.value,
    required this.size,
    required this.color,
    required this.wdth,
    required this.animate,
  });
  final String value;
  final double size, wdth;
  final Color color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    Widget face(double w, double wt) => Text(
          value,
          maxLines: 1,
          style: display(size, wdth: w, wght: wt, color: color, height: .95, letterSpacing: -size * .02)
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        );
    final body = animate
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) =>
                face(125 - (125 - wdth) * t, 300 + 600 * t),
          )
        : face(wdth, 900);
    return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: body);
  }
}

/// The PR stamp: lands big and tilted, settles flat.
class Stamp extends StatelessWidget {
  const Stamp({super.key, required this.text, this.visible = true});
  final String text;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Tone.pr, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: mono(10, color: Tone.ground, weight: FontWeight.w600, letterSpacing: 1)),
    );
    if (!visible) return const SizedBox.shrink();
    if (calm(context)) return chip;
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.rotate(
        angle: (1 - t) * -8 * math.pi / 180,
        child: Transform.scale(scale: 2.2 - 1.2 * t, child: child),
      ),
      child: chip,
    );
  }
}
