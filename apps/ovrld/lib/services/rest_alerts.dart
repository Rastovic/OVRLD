import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The rest timer outside the app: a silent countdown in the notification
/// shade while resting, and one buzz when rest is over - so the phone can be
/// in a pocket between sets.
class RestAlerts {
  RestAlerts._();
  static final instance = RestAlerts._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  static const _countdownId = 41;
  static const _doneId = 42;

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (_ready || !_android) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_stat_ovrld')),
      );
      _ready = true;
    } catch (e) {
      debugPrint('notifications unavailable: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _a =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Asked when the first session starts, never on launch.
  Future<void> askPermission() async {
    await init();
    if (!_ready) return;
    await _a?.requestNotificationsPermission();
  }

  /// Android 14+ denies exact alarms by default, so the "rest over" buzz
  /// can land late with the screen off. This opens the system page where it
  /// can be allowed. Returns whether it is allowed now.
  Future<bool> exactAllowed() async {
    await init();
    if (!_ready) return false;
    return await _a?.canScheduleExactNotifications() ?? false;
  }

  Future<void> askExact() async {
    await init();
    if (!_ready) return;
    await _a?.requestExactAlarmsPermission();
  }

  Future<void> start(DateTime endsAt, String next) async {
    await init();
    if (!_ready) return;
    final ms = endsAt.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) return;
    try {
      await _plugin.show(
        _countdownId,
        'Resting',
        'Next: $next',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_countdown',
            'Rest countdown',
            channelDescription: 'Silent countdown while you rest between sets',
            importance: Importance.low,
            priority: Priority.low,
            usesChronometer: true,
            chronometerCountDown: true,
            when: endsAt.millisecondsSinceEpoch,
            showWhen: true,
            ongoing: true,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            timeoutAfter: ms,
          ),
        ),
      );
      final exact = await _a?.canScheduleExactNotifications() ?? false;
      await _plugin.zonedSchedule(
        _doneId,
        'Rest over',
        'Next: $next',
        tz.TZDateTime.from(endsAt.toUtc(), tz.UTC),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_done',
            'Rest over',
            channelDescription: 'One buzz when your rest time is up',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 300, 150, 300]),
            timeoutAfter: 60000,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('rest alert failed: $e');
    }
  }

  Future<void> cancel() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_countdownId);
      await _plugin.cancel(_doneId);
    } catch (_) {}
  }
}
