import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../grid.dart';
import '../models.dart';
import 'api.dart';
import 'notifier.dart';
import 'settings.dart';
import 'widget_sync.dart';

/// Background monitoring: an Android foreground service that keeps polling the
/// gateway while the app is closed. Its ongoing notification is the phone's
/// version of the Windows tray icon (battery, load, grid at a glance), and it
/// fires the grid / low-battery alerts.
class MonitorService {
  static const pollSeconds = 15;
  static bool _initialized = false;

  /// iOS does not allow a long-running polling service, so on iPhone the app
  /// only watches (and alerts) while it is open.
  static bool get supported => Platform.isAndroid;

  static void init() {
    if (_initialized || !supported) return;
    _initialized = true;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'monitor_status',
        channelName: 'Live status',
        channelDescription: 'Battery, load and grid while monitoring in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(pollSeconds * 1000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Asks for notification permission and the battery-optimisation exemption
  /// Android needs to keep the service alive.
  static Future<void> requestPermissions() async {
    if (!supported) return;
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<bool> get isRunning async => supported && await FlutterForegroundTask.isRunningService;

  static Future<void> start() async {
    if (!supported) return;
    init();
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 4242,
      // Must match android:foregroundServiceType in AndroidManifest.xml. specialUse has no
      // daily time limit (dataSync is capped at 6 h a day on Android 15+).
      serviceTypes: [ForegroundServiceTypes.specialUse],
      notificationTitle: 'Pi Q6 Monitor',
      notificationText: 'Connecting…',
      callback: startMonitorCallback,
    );
  }

  static Future<void> stop() async {
    if (supported && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

@pragma('vm:entry-point')
void startMonitorCallback() {
  FlutterForegroundTask.setTaskHandler(MonitorTaskHandler());
}

/// Text for the ongoing notification, like the tray tooltip.
String statusTitle(Telemetry t, GridState? grid) {
  final g = switch (grid) {
    GridState.on => 'Grid ON',
    GridState.off => 'Grid OFF',
    _ => t.acInputVoltage >= defaultGridOnVoltage ? 'Grid ON' : 'Grid OFF',
  };
  return 'Battery ${t.battery}% · $g';
}

String statusText(Telemetry t) {
  final live = t.online ? '' : ' · not live';
  return 'Load ${t.loadPower.round()} W · Solar ${t.pvInputPower.round()} W$live';
}

class MonitorTaskHandler extends TaskHandler {
  Settings? _settings;
  ShineApi? _api;
  AlertEngine? _alerts;
  bool _busy = false;
  int _ticks = 0;
  GridState? _lastGrid;
  static const _fullEvery = 300 ~/ MonitorService.pollSeconds; // 5 minutes

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    _settings = await Settings.load();
    _api = ShineApi(_settings!);
    final notifier = Notifier();
    await notifier.init();
    _alerts = AlertEngine(notifier);
    await _tick();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _tick();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  Future<void> _tick() async {
    final s = _settings, api = _api, alerts = _alerts;
    if (s == null || api == null || alerts == null || _busy) return;
    _busy = true;
    try {
      await s.reload();
      if (!s.backgroundMonitoring || s.token == null) {
        await FlutterForegroundTask.stopService();
        return;
      }
      final t = await api.telemetry();
      await alerts.process(t, s);
      // Home screen widgets: live numbers every tick, grid history / forecast /
      // trend chart every 5 minutes (and right after a grid change).
      final full = _ticks % _fullEvery == 0 || alerts.grid.state != _lastGrid;
      _ticks++;
      _lastGrid = alerts.grid.state;
      if (full) {
        unawaited(WidgetSync.fetchAndPublish(s, api).catchError((_) {}));
      } else {
        unawaited(WidgetSync.publish(telemetry: t, threshold: s.batteryThreshold));
      }
      await FlutterForegroundTask.updateService(
        notificationTitle: statusTitle(t, alerts.grid.state),
        notificationText: statusText(t),
      );
    } on ApiException catch (e) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Pi Q6 Monitor',
        notificationText: e.unauthorized ? 'Signed out — open the app to sign in' : e.message,
      );
    } catch (_) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Pi Q6 Monitor',
        notificationText: 'No connection to the server',
      );
    } finally {
      _busy = false;
    }
  }
}
