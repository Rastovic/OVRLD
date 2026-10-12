import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../ui/common.dart';
import '../ui/kinetic.dart';
import '../ui/tokens.dart';

/// First-run walkthrough: one page per idea, each with a small live demo of
/// the thing it explains. Shown once after setup; YOU → Show walkthrough
/// brings it back.
Future<void> showTour(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const Tour()),
    );

class Tour extends StatefulWidget {
  const Tour({super.key});
  @override
  State<Tour> createState() => _TourState();
}

class _Page {
  const _Page(this.eyebrow, this.title, this.body, this.demo, this.color);
  final String eyebrow, title, body;
  final Widget demo;
  final Color color;
}

class _TourState extends State<Tour> {
  final ctl = PageController();
  int page = 0;

  static const pages = [
    _Page('1 · Today', 'Today', 'Opens on what is planned for today, in its split colour. Every exercise shows what you lifted last time and what to beat. Rest days just say REST.', _TodayDemo(), SplitColors.legs),
    _Page('2 · Log a set', 'Log', 'Tap + and − to set the weight and reps, then LOG SET. Beat your best and a PR stamp lands. The rest timer starts by itself and keeps counting in your notifications when the phone is locked.', _LogDemo(), Tone.bone),
    _Page('3 · Get stronger', 'Overload', 'When every set reaches the top of the rep range, the next session asks for a little more weight. Otherwise: same weight, one more rep. Small steps, every week.', _OverloadDemo(), SplitColors.pull),
    _Page('4 · Supersets', 'Supersets', 'In a workout, tap "Superset with next" to pair exercises. The logger then goes A1, A2, rest, A1, A2 - no rest until the round is done.', _SupersetDemo(), SplitColors.push),
    _Page('5 · Your week', 'Week', 'In WEEK, tap any day to make it a workout, cardio or rest. Build your own workouts there too, and keep more than one plan.', _WeekDemo(), SplitColors.upper),
    _Page('6 · Finish and rate', 'Rate', 'FINISH saves the time, volume and records. Rate your energy and how it felt - Reports puts it next to what you lifted.', _RateDemo(), SplitColors.full),
    _Page('7 · See it grow', 'Reports', 'Strength per exercise, training days by split colour, running pace, body weight. Log cardio from HISTORY or a cardio day.', _ReportDemo(), SplitColors.cardio),
    _Page('8 · Home screen', 'Widget', 'Long-press your home screen → Widgets → OVRLD. It shows today\'s split, or REST, and turns over at midnight by itself.', _WidgetDemo(), SplitColors.legs),
  ];

  Future<void> done() async {
    final app = AppScope.read(context);
    if (!app.profile.tourSeen) {
      app.profile.tourSeen = true;
      await app.repo.saveProfile(app.profile);
      await app.changed();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = page == pages.length - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) done();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(children: [
                Expanded(child: Text(pages[page].eyebrow.toUpperCase(), style: label(color: pages[page].color))),
                TextButton(onPressed: done, child: Text('SKIP', style: mono(12, color: Tone.mute, weight: FontWeight.w600))),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: ctl,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => page = i),
                itemBuilder: (c, i) => _PageView(p: pages[i], active: i == page),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == page ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == page ? pages[page].color : Tone.raised,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ]),
                const SizedBox(height: 14),
                BigButton(
                  last ? "Let's lift" : 'Next',
                  color: pages[page].color,
                  onPressed: () => last
                      ? done()
                      : ctl.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.p, required this.active});
  final _Page p;
  final bool active;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        children: [
          VaryText(
            p.title,
            key: ValueKey('${p.title}$active'),
            size: 84,
            wdth: 125,
            wght: 900,
            fromWdth: 62,
            fromWght: 200,
            color: p.color,
            duration: const Duration(milliseconds: 800),
          ),
          const SizedBox(height: 18),
          // The demos are pictures of the app, not reading text: their type
          // is held near 100% so they keep their shape at large font sizes.
          SizedBox(
            height: 270,
            child: active
                ? MediaQuery.withClampedTextScaling(maxScaleFactor: 1.05, child: p.demo)
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),
          Text(p.body, style: mono(13.5, color: Tone.bone, height: 1.6)),
        ],
      );
}

/// Steps through [count] states every [every].
mixin _Cycle<T extends StatefulWidget> on State<T> {
  int tick = 0;
  Timer? _t;
  Duration get every => const Duration(milliseconds: 1400);
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(every, (_) {
      if (mounted) setState(() => tick++);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Tone.surface,
          border: Border.all(color: Tone.line),
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _TodayDemo extends StatelessWidget {
  const _TodayDemo();
  @override
  Widget build(BuildContext context) => _Frame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Transform.translate(offset: const Offset(-16, 0), child: const Marquee('Leg day', color: SplitColors.legs, size: 70)),
          const SizedBox(height: 10),
          for (final (n, l) in const [
            ('BACK SQUAT', 'last 100 × 8·8·7·7 → 100 × 8'),
            ('ROMANIAN DEADLIFT', 'last 90 × 10·10·10 → 92.5 × 8'),
          ])
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tone.line))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n, style: display(15, wdth: 80, wght: 700)),
                Text(l, style: mono(11)),
              ]),
            ),
        ]),
      );
}

class _LogDemo extends StatefulWidget {
  const _LogDemo();
  @override
  State<_LogDemo> createState() => _LogDemoState();
}

class _LogDemoState extends State<_LogDemo> with _Cycle {
  static const weights = ['100', '102.5', '105', '102.5'];
  @override
  Widget build(BuildContext context) {
    final w = weights[tick % weights.length];
    return _Frame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BACK SQUAT', style: display(26, wdth: 70, wght: 850)),
        const SizedBox(height: 8),
        Row(children: [
          const Lbl('Weight'),
          const SizedBox(width: 8),
          Stamp(text: 'PR', visible: w == '105'),
        ]),
        RollingNumber(w, size: 96),
        Row(children: [
          Expanded(child: Text('kg', style: mono(12))),
          _fakeStep('−2.5', false),
          const SizedBox(width: 8),
          _fakeStep('+2.5', tick % weights.length != 3),
        ]),
      ]),
    );
  }

  Widget _fakeStep(String t, bool hot) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 54,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hot ? Tone.bone : Tone.raised,
          border: Border.all(color: Tone.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(t, style: mono(13, color: hot ? Tone.ground : Tone.bone)),
      );
}

class _OverloadDemo extends StatelessWidget {
  const _OverloadDemo();
  @override
  Widget build(BuildContext context) {
    Widget row(String week, String sets, String note, {bool up = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tone.line))),
          child: Row(children: [
            SizedBox(width: 42, child: Text(week, style: mono(11))),
            Expanded(child: Text(sets, style: mono(13, color: Tone.bone))),
            Text(note, style: mono(11, color: up ? SplitColors.pull : Tone.mute, weight: up ? FontWeight.w600 : FontWeight.w400)),
          ]),
        );
    return _Frame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TARGET 6–8 REPS', style: label()),
        const SizedBox(height: 6),
        row('W1', '100 × 8·7·7·6', 'beat reps'),
        row('W2', '100 × 8·8·8·7', 'beat reps'),
        row('W3', '100 × 8·8·8·8', 'all at 8 →'),
        row('W4', '102.5 × 6·6·6·6', '+2.5 kg', up: true),
      ]),
    );
  }
}

class _SupersetDemo extends StatefulWidget {
  const _SupersetDemo();
  @override
  State<_SupersetDemo> createState() => _SupersetDemoState();
}

class _SupersetDemoState extends State<_SupersetDemo> with _Cycle {
  static const steps = ['A1', 'A2', 'REST'];
  @override
  Widget build(BuildContext context) {
    final s = steps[tick % 3];
    Widget item(String lbl, String name) {
      final on = s == lbl;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? SplitColors.push.withValues(alpha: .16) : Tone.ground,
          border: Border(left: BorderSide(color: SplitColors.push, width: on ? 4 : 2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Text(lbl, style: mono(12, color: SplitColors.push, weight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(
            child: VaryText(name, size: 22, wdth: on ? 110 : 70, wght: on ? 900 : 400,
                color: on ? Tone.bone : Tone.mute, duration: const Duration(milliseconds: 350)),
          ),
        ]),
      );
    }

    return _Frame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        item('A1', 'Lateral raise'),
        item('A2', 'Triceps pushdown'),
        const SizedBox(height: 6),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: s == 'REST' ? 1 : .25,
          child: Row(children: [
            const Icon(Icons.timer_outlined, color: Tone.bone, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text('REST 1:30 · then round 2', style: mono(13, color: Tone.bone))),
          ]),
        ),
      ]),
    );
  }
}

class _WeekDemo extends StatelessWidget {
  const _WeekDemo();
  @override
  Widget build(BuildContext context) {
    const days = [
      ('MON', 'Legs', SplitColors.legs, 125.0),
      ('TUE', 'Push', SplitColors.push, 118.0),
      ('WED', 'Rest', SplitColors.rest, 90.0),
      ('THU', 'Pull', SplitColors.pull, 125.0),
      ('FRI', 'Upper', SplitColors.upper, 100.0),
      ('SAT', 'Run', SplitColors.cardio, 125.0),
    ];
    return _Frame(
      child: Column(children: [
        for (var i = 0; i < days.length; i++)
          Row(children: [
            SizedBox(width: 40, child: Text(days[i].$1, style: mono(10.5))),
            Expanded(
              child: VaryText(
                days[i].$2,
                size: 32,
                wdth: days[i].$4,
                wght: days[i].$2 == 'Rest' ? 150 : 850,
                fromWdth: 62,
                color: days[i].$3,
                delay: Duration(milliseconds: 90 * i),
                duration: const Duration(milliseconds: 1000),
              ),
            ),
          ]),
      ]),
    );
  }
}

class _RateDemo extends StatefulWidget {
  const _RateDemo();
  @override
  State<_RateDemo> createState() => _RateDemoState();
}

class _RateDemoState extends State<_RateDemo> with _Cycle {
  static const words = ['Empty', 'Low', 'Okay', 'Strong', 'Beast'];
  @override
  Widget build(BuildContext context) {
    final pick = [3, 4, 2, 3][tick % 4];
    return _Frame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < words.length; i++)
          VaryText(
            words[i],
            size: 34,
            wdth: i == pick ? 125 : 62,
            wght: i == pick ? 900 : 200,
            color: i == pick ? Tone.bone : SplitColors.rest,
          ),
      ]),
    );
  }
}

class _ReportDemo extends StatelessWidget {
  const _ReportDemo();
  @override
  Widget build(BuildContext context) => _Frame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('SQUAT EST. 1RM', style: display(18, wdth: 75, wght: 800))),
            Text('+17 kg', style: mono(11, color: SplitColors.pull, weight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              builder: (c, t, _) => CustomPaint(size: Size.infinite, painter: _GrowLine(t)),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            for (final c in const [SplitColors.legs, SplitColors.push, null, SplitColors.pull, SplitColors.upper, SplitColors.cardio, null])
              Expanded(
                child: Container(
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: c ?? Tone.raised, borderRadius: BorderRadius.circular(4)),
                ),
              ),
          ]),
        ]),
      );
}

class _GrowLine extends CustomPainter {
  _GrowLine(this.t);
  final double t;
  static const ys = [112.0, 114, 116, 116, 119, 121, 121, 124, 126, 129];
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Tone.line;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final n = (ys.length * t).clamp(1, ys.length).ceil();
    final path = Path();
    for (var i = 0; i < n; i++) {
      final o = Offset(size.width * i / (ys.length - 1), size.height * (1 - (ys[i] - 110) / 20));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, Paint()
      ..color = SplitColors.legs
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round);
    final last = Offset(size.width * (n - 1) / (ys.length - 1), size.height * (1 - (ys[n - 1] - 110) / 20));
    canvas.drawCircle(last, 5, Paint()..color = Tone.bone);
  }

  @override
  bool shouldRepaint(_GrowLine old) => old.t != t;
}

class _WidgetDemo extends StatefulWidget {
  const _WidgetDemo();
  @override
  State<_WidgetDemo> createState() => _WidgetDemoState();
}

class _WidgetDemoState extends State<_WidgetDemo> with _Cycle {
  @override
  Duration get every => const Duration(milliseconds: 2200);
  @override
  Widget build(BuildContext context) {
    final rest = tick.isOdd;
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: Container(
          key: ValueKey(rest),
          width: 190,
          height: 190,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: rest ? Tone.surface : SplitColors.legs,
            border: Border.all(color: rest ? Tone.line : SplitColors.legs),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rest ? 'WED 14 OCT' : 'TODAY', style: label(color: rest ? Tone.mute : Tone.ground)),
            const Spacer(),
            rest
                ? const KText('Rest', size: 64, wdth: 62, wght: 120)
                : const KText('Legs', size: 64, wdth: 62, wght: 900, color: Tone.ground),
            const Spacer(),
            Text(rest ? 'Next: pull' : '5 ex · ~45 min', style: mono(11, color: rest ? Tone.mute : Tone.ground)),
          ]),
        ),
      ),
    );
  }
}
