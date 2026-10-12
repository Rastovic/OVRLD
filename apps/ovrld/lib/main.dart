import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'data/repo.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'services/rest_alerts.dart';
import 'state/app_state.dart';
import 'ui/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Archivo'], await rootBundle.loadString('assets/fonts/OFL-Archivo.txt'));
    yield LicenseEntryWithLineBreaks(['IBM Plex Mono'], await rootBundle.loadString('assets/fonts/OFL-PlexMono.txt'));
  });
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Tone.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final repo = await Repo.open(p.join(await getDatabasesPath(), 'ovrld.db'));
  final app = AppState(repo);
  await app.load();
  RestAlerts.instance.init();
  runApp(OvrldApp(state: app));
}

class OvrldApp extends StatelessWidget {
  const OvrldApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: MaterialApp(
          title: 'OVRLD',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: const _Root(),
        ),
      );
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return app.profile.onboarded ? const Shell() : const Onboarding();
  }
}
