import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../ui/tokens.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'tour.dart';
import 'today_screen.dart';
import 'week_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !AppScope.read(context).profile.tourSeen) showTour(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app on a new day must show the new day.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) AppScope.read(context).changed();
  }

  static const tabs = [
    (Icons.bolt_outlined, Icons.bolt, 'Today'),
    (Icons.view_week_outlined, Icons.view_week, 'Week'),
    (Icons.history_outlined, Icons.history, 'History'),
    (Icons.show_chart_outlined, Icons.show_chart, 'Reports'),
    (Icons.person_outline, Icons.person, 'You'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [TodayScreen(), WeekScreen(), HistoryScreen(), ReportsScreen(), ProfileScreen()],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Tone.surface,
          indicatorColor: Tone.raised,
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => mono(10.5,
                color: s.contains(WidgetState.selected) ? Tone.bone : Tone.mute,
                weight: FontWeight.w500,
                letterSpacing: .8),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Tone.bone : Tone.mute),
          ),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: [
            for (final (icon, sel, name) in tabs)
              NavigationDestination(icon: Icon(icon), selectedIcon: Icon(sel), label: name.toUpperCase()),
          ],
        ),
      ),
    );
  }
}
