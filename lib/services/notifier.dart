import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../grid.dart';
import '../models.dart';
import 'alerts.dart';
import 'settings.dart';

/// Posts grid / battery alerts as Android notifications with their own sounds
/// (res/raw/grid_on, grid_off, low_battery) and speaks the low-battery warning.
class Notifier {
  static const _gridOnChannel = 'grid_on';
  static const _gridOffChannel = 'grid_off';
  static const _gridSilentChannel = 'grid_silent';
  static const _batteryChannel = 'low_battery';

  static const _gridId = 1001;
  static const _batteryId = 1002;

  final _plugin = FlutterLocalNotificationsPlugin();
  FlutterTts? _tts;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // iPhone: permission is asked after sign-in (requestPermission).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _gridOnChannel,
      'Grid power back',
      description: 'Utility electricity came back',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('grid_on'),
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _gridOffChannel,
      'Grid power off',
      description: 'Utility electricity went off',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('grid_off'),
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _gridSilentChannel,
      'Grid changes (silent)',
      description: 'Grid on/off without a sound',
      importance: Importance.defaultImportance,
      playSound: false,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _batteryChannel,
      'Low battery alarm',
      description: 'Battery dropped below your alert level',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('low_battery'),
    ));
    _ready = true;
  }

  /// iPhone: asks for notification permission (Android asks via the background service).
  Future<void> requestPermission() async {
    await init();
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    } catch (_) {}
  }

  Future<void> gridChanged(GridState state, {required bool sound}) async {
    await init();
    final on = state == GridState.on;
    final channel = !sound ? _gridSilentChannel : (on ? _gridOnChannel : _gridOffChannel);
    await _plugin.show(
      id: _gridId,
      title: on ? 'Grid power is back' : 'Grid power is off',
      body: on ? 'Utility electricity is on.' : 'Running on battery / solar.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel == _gridSilentChannel ? 'Grid changes (silent)' : (on ? 'Grid power back' : 'Grid power off'),
          importance: sound ? Importance.high : Importance.defaultImportance,
          priority: Priority.high,
          playSound: sound,
          sound: sound ? RawResourceAndroidNotificationSound(on ? 'grid_on' : 'grid_off') : null,
          color: on ? gridOnColor : const Color(0xFFF87171),
          category: AndroidNotificationCategory.status,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: sound),
      ),
    );
  }

  Future<void> lowBattery(int battery, int threshold, {required bool voice}) async {
    await init();
    await _plugin.show(
      id: _batteryId,
      title: 'CRITICAL BATTERY',
      body: 'Battery is at $battery%, below your $threshold% alert level. Reduce the load if you can.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _batteryChannel,
          'Low battery alarm',
          importance: Importance.max,
          priority: Priority.max,
          sound: RawResourceAndroidNotificationSound('low_battery'),
          category: AndroidNotificationCategory.alarm,
          color: Color(0xFFF87171),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
    if (voice) {
      // Let the siren play first, then speak (same as the Windows tray app).
      await Future<void>.delayed(const Duration(seconds: 3));
      await speak('Warning. Battery is low. $battery percent remaining. Please reduce the load.');
    }
  }

  Future<void> speak(String text) async {
    try {
      _tts ??= FlutterTts();
      await _tts!.setSpeechRate(0.45);
      await _tts!.setVolume(1.0);
      await _tts!.speak(text);
    } catch (_) {
      // No TTS engine on the device; the notification sound already played.
    }
  }
}

/// Runs the alert rules on each reading and fires notifications.
class AlertEngine {
  final Notifier notifier;
  final GridWatcher grid = GridWatcher();
  final LowBatteryGate battery = LowBatteryGate();

  AlertEngine(this.notifier);

  /// Returns the grid state that was just confirmed, if any.
  Future<GridState?> process(Telemetry t, Settings s) async {
    final change = grid.update(t);
    if (change != null) {
      await notifier.gridChanged(change, sound: s.gridSoundsEnabled);
    }
    if (t.online || t.timestamp != null) {
      final threshold = s.batteryThreshold;
      if (battery.shouldAlert(t.battery, threshold, DateTime.now()) && s.alarmEnabled) {
        await notifier.lowBattery(t.battery, threshold, voice: s.voiceEnabled);
      }
    }
    return change;
  }
}
