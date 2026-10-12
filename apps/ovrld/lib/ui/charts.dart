import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ovrld_core/ovrld_core.dart';

import 'tokens.dart';

/// Round tick values covering [lo, hi]: 1, 2, 2.5 or 5 × 10^n steps.
List<double> niceTicks(double lo, double hi, {int target = 3}) {
  if (hi <= lo) {
    final pad = lo == 0 ? 1.0 : lo.abs() * .1;
    lo -= pad;
    hi += pad;
  }
  final raw = (hi - lo) / target;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final step = [1.0, 2.0, 2.5, 5.0, 10.0].map((m) => m * mag).firstWhere((s) => s >= raw);
  final start = (lo / step).floor() * step;
  final end = (hi / step).ceil() * step;
  return [for (var v = start; v <= end + step * 1e-6; v += step) v];
}

/// A time series: line, faint area, grid at round values, last point marked.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.points,
    required this.color,
    required this.format,
    this.height = 150,
    this.invert = false,
  });
  final List<(DateTime, double)> points;
  final Color color;
  final String Function(double) format;
  final double height;

  /// Lower is better (pace): the axis runs upside down so up still means good.
  final bool invert;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(height: height, child: Center(child: Text('Nothing logged yet', style: mono(12))));
    }
    return Semantics(
      label: 'Chart from ${format(points.first.$2)} to ${format(points.last.$2)}',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _LinePainter(points, color, format, invert)),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.points, this.color, this.format, this.invert);
  final List<(DateTime, double)> points;
  final Color color;
  final String Function(double) format;
  final bool invert;

  @override
  void paint(Canvas canvas, Size size) {
    final ys = points.map((p) => p.$2);
    final ticks = niceTicks(ys.reduce(math.min), ys.reduce(math.max));
    final lo = ticks.first, hi = ticks.last;
    final labelStyle = mono(9.5);
    var axisW = 0.0;
    for (final t in ticks) {
      final tp = TextPainter(text: TextSpan(text: format(t), style: labelStyle), textDirection: TextDirection.ltr)..layout();
      axisW = math.max(axisW, tp.width);
    }
    final left = axisW + 8;
    const top = 6.0, bottom = 18.0;
    final w = size.width - left - 6;
    final h = size.height - top - bottom;
    double y(double v) {
      final f = (v - lo) / (hi - lo);
      return top + (invert ? f : 1 - f) * h;
    }

    final t0 = points.first.$1.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.$1.millisecondsSinceEpoch.toDouble();
    double x(DateTime d) => points.length == 1 || t1 == t0
        ? left + w / 2
        : left + (d.millisecondsSinceEpoch - t0) / (t1 - t0) * w;

    final grid = Paint()
      ..color = Tone.line
      ..strokeWidth = 1;
    for (final t in ticks) {
      canvas.drawLine(Offset(left, y(t)), Offset(left + w, y(t)), grid);
      final tp = TextPainter(text: TextSpan(text: format(t), style: labelStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(left - 6 - tp.width, y(t) - tp.height / 2));
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(points[i].$1), y(points[i].$2));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    if (points.length > 1) {
      final area = Path.from(path)
        ..lineTo(x(points.last.$1), top + h)
        ..lineTo(x(points.first.$1), top + h)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: .14));
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final p in points) {
      canvas.drawCircle(Offset(x(p.$1), y(p.$2)), 2.2, Paint()..color = color);
    }
    final last = Offset(x(points.last.$1), y(points.last.$2));
    canvas.drawCircle(last, 4.5, Paint()..color = Tone.bone);

    String d(DateTime t) => '${t.day} ${monthShort[t.month - 1]}';
    final a = TextPainter(text: TextSpan(text: d(points.first.$1), style: labelStyle), textDirection: TextDirection.ltr)..layout();
    a.paint(canvas, Offset(left, size.height - a.height));
    if (points.length > 1) {
      final b = TextPainter(text: TextSpan(text: d(points.last.$1), style: labelStyle), textDirection: TextDirection.ltr)..layout();
      b.paint(canvas, Offset(left + w - b.width, size.height - b.height));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.points != points || old.color != color;
}

/// Vertical bars with a label under each and the value above the tallest.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.bars, required this.color, required this.format, this.height = 120});
  final List<(String, double)> bars;
  final Color color;
  final String Function(double) format;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = bars.isEmpty ? 0.0 : bars.map((b) => b.$2).reduce(math.max);
    return SizedBox(
      height: height,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final (lbl, v) in bars)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (v > 0 && v == max) Text(format(v), style: mono(9, color: Tone.bone), maxLines: 1),
                const SizedBox(height: 2),
                Flexible(
                  child: FractionallySizedBox(
                    heightFactor: max <= 0 ? 0 : (v / max).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: v == max ? color : color.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(lbl, style: mono(8.5), maxLines: 1),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Horizontal bars, one per row: muscles, splits.
class HBars extends StatelessWidget {
  const HBars({super.key, required this.rows, required this.color, required this.format});
  final List<(String, double)> rows;
  final Color color;
  final String Function(double) format;
  @override
  Widget build(BuildContext context) {
    final max = rows.isEmpty ? 0.0 : rows.map((r) => r.$2).reduce(math.max);
    return Column(children: [
      for (final (lbl, v) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 86, child: Text(lbl, style: mono(11, color: Tone.bone), overflow: TextOverflow.ellipsis)),
            Expanded(
              child: LayoutBuilder(
                builder: (c, k) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 12,
                    width: max <= 0 ? 0 : k.maxWidth * (v / max),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
            ),
            SizedBox(width: 44, child: Text(format(v), style: mono(11), textAlign: TextAlign.right)),
          ]),
        ),
    ]);
  }
}

/// Energy (1-5) against session volume: one dot per session.
class Scatter extends StatelessWidget {
  const Scatter({super.key, required this.points, required this.color, required this.formatX, this.height = 140});
  final List<(double, int)> points;
  final Color color;
  final String Function(double) formatX;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _ScatterPainter(points, color, formatX)),
      );
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter(this.points, this.color, this.formatX);
  final List<(double, int)> points;
  final Color color;
  final String Function(double) formatX;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 46.0, bottom = 18.0, top = 6.0;
    final w = size.width - left - 8, h = size.height - bottom - top;
    final xs = points.map((p) => p.$1);
    final ticks = niceTicks(xs.isEmpty ? 0 : xs.reduce(math.min), xs.isEmpty ? 1 : xs.reduce(math.max));
    final lo = ticks.first, hi = ticks.last;
    final grid = Paint()..color = Tone.line;
    final st = mono(9.5);
    const words = ['Empty', 'Low', 'Okay', 'Strong', 'Beast'];
    for (var e = 1; e <= 5; e++) {
      final yy = top + (1 - (e - 1) / 4) * h;
      canvas.drawLine(Offset(left, yy), Offset(left + w, yy), grid);
      final tp = TextPainter(text: TextSpan(text: words[e - 1], style: st), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(left - 6 - tp.width, yy - tp.height / 2));
    }
    for (final t in [ticks.first, ticks.last]) {
      final tp = TextPainter(text: TextSpan(text: formatX(t), style: st), textDirection: TextDirection.ltr)..layout();
      final xx = left + (t - lo) / (hi - lo) * w;
      tp.paint(canvas, Offset((xx - tp.width / 2).clamp(left, left + w - tp.width), size.height - tp.height));
    }
    for (final (x, e) in points) {
      final o = Offset(left + (x - lo) / (hi - lo) * w, top + (1 - (e - 1) / 4) * h);
      canvas.drawCircle(o, 4, Paint()..color = color.withValues(alpha: .75));
    }
  }

  @override
  bool shouldRepaint(_ScatterPainter old) => old.points != points;
}
