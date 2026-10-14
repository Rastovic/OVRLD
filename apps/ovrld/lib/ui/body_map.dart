import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Front and back of the body as flat facets, coloured per muscle. The
/// approved drawing from design/body-preview.html: half a figure right of the
/// midline x = 100, mirrored for the left. Several facets can belong to one
/// muscle (quads are three heads, calves two heads and the soleus).
enum BodySide { front, back }

const _front = <(String, String)>[
  ('Traps', '112,58 118,66 134,76 113,74'),
  ('Front delts', '124,80 138,76 144,88 140,110 134,114 128,98'),
  ('Side delts', '139,75 151,79 159,92 159,110 151,122 141,110 145,88'),
  ('Chest', '101,79 123,79 128,96 101,100'),
  ('Chest', '101,102 129,98 134,114 128,132 114,140 101,138'),
  ('Biceps', '140,115 149,123 152,146 148,168 140,170 136,150 136,128'),
  ('Triceps', '152,124 160,114 163,140 157,166 151,168 153,146'),
  ('Forearms', '139,175 149,173 157,197 161,247 155,249 145,214'),
  ('Forearms', '151,172 164,170 170,192 172,245 163,247 159,196'),
  ('Abs', '101,142 117,140 118,159 101,160'),
  ('Abs', '101,162 118,161 118,180 101,181'),
  ('Abs', '101,183 118,182 117,201 101,202'),
  ('Abs', '101,204 117,203 112,232 101,242'),
  ('Obliques', '120,142 130,150 137,172 139,198 134,212 120,224'),
  ('Abductors', '134,216 143,222 145,248 136,242'),
  ('Adductors', '104,250 117,240 123,252 121,290 112,300 106,280'),
  ('Quads', '124,248 135,240 141,262 139,300 133,322 126,312 123,280'),
  ('Quads', '139,236 146,250 148,282 146,316 138,330 136,322 141,300 143,262'),
  ('Quads', '112,303 121,286 125,312 132,325 124,334 114,327'),
  ('Calves', '128,356 136,352 138,380 134,404 129,404'),
  ('Calves', '139,352 146,360 146,384 140,400 138,380'),
  ('Calves', '116,352 126,356 126,388 120,398 114,378'),
];

const _back = <(String, String)>[
  ('Traps', '100,52 110,56 118,70 138,80 128,90 114,100 106,122 100,150'),
  ('Rear delts', '132,84 149,80 159,94 157,112 148,110 140,98'),
  ('Side delts', '151,78 160,82 166,98 162,114 159,112 161,94'),
  ('Upper back', '117,101 130,93 144,100 146,114 136,126 120,130 109,127 112,111'),
  ('Lats', '104,148 109,130 122,133 138,128 147,118 150,134 146,162 136,190 124,206 110,204'),
  ('Lower back', '102,152 107,152 111,206 122,210 116,226 102,230'),
  ('Obliques', '137,194 145,172 145,202 139,216 126,213'),
  ('Triceps', '151,116 161,114 165,140 159,160 153,150'),
  ('Triceps', '140,112 149,116 152,150 150,168 142,168 138,140'),
  ('Forearms', '142,174 151,171 161,196 163,247 156,249 148,214'),
  ('Forearms', '153,170 166,170 172,196 172,245 165,247 163,196'),
  ('Abductors', '119,212 133,208 145,219 143,237 131,229 119,224'),
  ('Glutes', '101,234 117,226 133,232 144,242 142,268 128,282 110,282 101,272'),
  ('Hamstrings', '125,288 142,276 146,300 142,330 134,340 129,316'),
  ('Hamstrings', '105,290 122,288 127,318 131,340 122,344 112,326 105,306'),
  ('Calves', '106,358 120,354 124,380 118,396 108,384'),
  ('Calves', '122,354 136,352 142,368 136,392 126,390 124,374'),
  ('Calves', '111,398 120,399 131,394 129,412 115,412'),
];

/// Neck, hands, knees, feet and the serratus: drawn, never coloured.
const _inertFront = [
  '100,56 111,54 113,68 108,76 100,78',
  '129,134 140,125 142,133',
  '131,142 142,137 143,148',
  '133,152 142,149 141,160',
  '156,251 174,249 180,270 176,288 164,290 158,272',
  '118,336 134,332 137,347 128,353 118,348',
  '122,408 138,406 142,428 120,432',
];
const _inertBack = [
  '100,54 108,54 110,58 100,60',
  '143,170 165,168 166,172 143,174',
  '156,251 174,249 180,270 176,288 164,290 158,272',
  '115,346 137,344 137,352 116,355',
  '116,414 130,414 133,432 118,434',
];

const _viewLeft = 18.0, _viewWidth = 164.0, _viewHeight = 440.0;

/// Width over height of one figure.
const bodyAspect = _viewWidth / _viewHeight;

/// The facets were drawn with a long torso. This puts the crotch at half
/// height and the knee at three quarters, as in an 8-head figure.
const _height = [(0.0, 0.0), (140.0, 130.0), (250.0, 230.0), (345.0, 330.0), (434.0, 436.0), (440.0, 440.0)];

/// Female figure: width factor by height. Narrower shoulders and waist, a
/// wider pelvis; waist to hips comes out near 0.7.
const _femaleWidth = [
  (0.0, .94), (60.0, .88), (80.0, .84), (120.0, .86), (160.0, .84), (185.0, .8),
  (212.0, 1.0), (240.0, 1.14), (275.0, 1.1), (335.0, .97), (440.0, .92),
];

double _lerp(List<(double, double)> pts, double v) {
  for (var i = 1; i < pts.length; i++) {
    final (a, fa) = pts[i - 1];
    final (b, fb) = pts[i];
    if (v <= b) return fa + (v - a) / (b - a) * (fb - fa);
  }
  return pts.last.$2;
}

Offset _place(double x, double y, bool female) {
  final ny = _lerp(_height, y);
  final k = female ? _lerp(_femaleWidth, ny) : 1.0;
  return Offset(100 + (x - 100) * k, ny);
}

/// The lower chest is rounder on the female figure.
const _chestLower = '101,102 129,98 134,114 128,132 114,140 101,138';
const _chestLowerFemale = '101,101 127,97 137,113 137,133 128,149 112,153 101,147';

List<Offset> _points(String s, bool female, {bool mirror = false}) => [
      for (final p in s.split(' '))
        _place(
          mirror ? 200 - double.parse(p.split(',')[0]) : double.parse(p.split(',')[0]),
          double.parse(p.split(',')[1]),
          female,
        ),
    ];

Path _path(List<Offset> pts) => Path()..addPolygon(pts, true);

class _Facet {
  _Facet(this.muscle, this.path);
  final String? muscle;
  final Path path;
}

final _cache = <(BodySide, bool), List<_Facet>>{};

List<_Facet> _facets(BodySide side, bool female) => _cache.putIfAbsent((side, female), () {
      final muscles = side == BodySide.front ? _front : _back;
      final inert = side == BodySide.front ? _inertFront : _inertBack;
      final head = _place(100, 31, female);
      return [
        _Facet(null, Path()..addOval(Rect.fromCenter(center: head, width: female ? 34.5 : 36, height: 48))),
        for (final s in inert) ...[
          _Facet(null, _path(_points(s, female))),
          _Facet(null, _path(_points(s, female, mirror: true))),
        ],
        for (final (m, raw) in muscles) ...[
          for (final mirror in [false, true])
            _Facet(m, _path(_points(female && raw == _chestLower ? _chestLowerFemale : raw, female, mirror: mirror))),
        ],
      ];
    });

/// The muscles drawn on one side, for tests and semantics.
Set<String> musclesOn(BodySide side) => {for (final (m, _) in side == BodySide.front ? _front : _back) m};

class BodyMap extends StatelessWidget {
  const BodyMap({
    super.key,
    required this.side,
    required this.colorOf,
    this.female = false,
    this.selected,
    this.untrained = const {},
    this.onTap,
  });
  final BodySide side;
  final Color Function(String muscle) colorOf;
  final bool female;
  final String? selected;

  /// Outlined in dashed red: nothing in the window.
  final Set<String> untrained;
  final ValueChanged<String?>? onTap;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: bodyAspect,
        child: LayoutBuilder(builder: (context, c) {
          final scale = c.maxWidth / _viewWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onTap == null
                ? null
                : (d) {
                    final p = Offset(d.localPosition.dx / scale + _viewLeft, d.localPosition.dy / scale);
                    final hit = _facets(side, female).reversed.where((f) => f.muscle != null && f.path.contains(p)).firstOrNull;
                    onTap!(hit?.muscle);
                  },
            child: Semantics(
              label: '${side == BodySide.front ? 'Front' : 'Back'} of the body, muscles coloured by sets',
              child: CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: _BodyPainter(side, female, colorOf, selected, untrained),
              ),
            ),
          );
        }),
      );
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.side, this.female, this.colorOf, this.selected, this.untrained);
  final BodySide side;
  final bool female;
  final Color Function(String) colorOf;
  final String? selected;
  final Set<String> untrained;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewWidth;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-_viewLeft, 0);
    final gap = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..color = Tone.surface;
    final dashed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Tone.danger;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..color = Tone.bone;
    for (final f in _facets(side, female)) {
      final m = f.muscle;
      var color = m == null ? Heat.inert : colorOf(m);
      if (m != null && selected != null && m != selected) color = color.withValues(alpha: .28);
      canvas.drawPath(f.path, Paint()..color = color);
      canvas.drawPath(f.path, gap);
      if (m == null) continue;
      if (m == selected) {
        canvas.drawPath(f.path, ring);
      } else if (untrained.contains(m) && selected == null) {
        canvas.drawPath(_dash(f.path, 3, 2), dashed);
      }
    }
    canvas.restore();
  }

  static Path _dash(Path p, double on, double off) {
    final out = Path();
    for (final ui.PathMetric m in p.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += on + off) {
        out.addPath(m.extractPath(d, (d + on).clamp(0, m.length)), Offset.zero);
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.selected != selected || old.side != side || old.female != female || old.untrained != untrained || old.colorOf != colorOf;
}
