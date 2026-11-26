import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/monitor_service.dart';
import '../services/notifier.dart';
import '../services/settings.dart';
import '../services/widget_sync.dart';

enum LoadStatus { loading, ready, unavailable, error }

enum AuthStatus { starting, signedOut, signedIn }

/// Everything the screens show. Mirrors the web app's AuthContext: telemetry
/// every 10 s, grid history and forecast every 2 min, while the app is open.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  static const telemetryEvery = Duration(seconds: 10);
  static const gridEvery = Duration(minutes: 2);

  /// Rows of recent history kept for the live chart (one row a minute = 4 hours).
  static const liveHistoryLimit = 240;

  final Settings settings;
  final ShineApi api;
  final AlertEngine _alerts = AlertEngine(Notifier());

  AppState(this.settings) : api = ShineApi(settings);

  AuthStatus auth = AuthStatus.starting;
  bool loggingIn = false;
  bool refreshing = false;
  String? error;

  Telemetry? telemetry;
  DateTime? lastUpdate;
  List<HistoryLog> history = [];
  List<Device> devices = [];

  GridResponse? grid;
  LoadStatus gridStatus = LoadStatus.loading;
  GridForecast? forecast;
  LoadStatus forecastStatus = LoadStatus.loading;

  Timer? _telemetryTimer;
  Timer? _gridTimer;
  bool _foreground = true;

  int get threshold => settings.batteryThreshold;

  Future<void> bootstrap() async {
    WidgetsBinding.instance.addObserver(this);
    if (settings.token != null) {
      auth = AuthStatus.signedIn;
      notifyListeners();
      _startPolling();
      unawaited(refreshDevices());
      unawaited(_syncBackgroundService());
    } else {
      auth = AuthStatus.signedOut;
      notifyListeners();
    }
  }

  Future<void> login(String user, String pass, bool remember) async {
    loggingIn = true;
    error = null;
    notifyListeners();
    try {
      await api.login(user, pass);
      await settings.setUsername(user);
      await settings.setRemember(remember);
      await settings.savePassword(remember ? pass : null);
      auth = AuthStatus.signedIn;
      _startPolling();
      await refreshDevices();
      await _alerts.notifier.requestPermission();
      await MonitorService.requestPermissions();
      await _syncBackgroundService();
    } on ApiException catch (e) {
      error = e.message;
    } on TimeoutException {
      error = 'The server took too long to answer. It may be waking up — try again.';
    } catch (e) {
      error = 'Could not reach the server. Check the address and your connection.';
    } finally {
      loggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _stopPolling();
    await MonitorService.stop();
    await api.logout();
    await settings.clearSession();
    unawaited(WidgetSync.signedOut());
    auth = AuthStatus.signedOut;
    telemetry = null;
    history = [];
    devices = [];
    grid = null;
    forecast = null;
    gridStatus = LoadStatus.loading;
    forecastStatus = LoadStatus.loading;
    notifyListeners();
  }

  // --- polling ---

  void _startPolling() {
    _stopPolling();
    refreshTelemetry();
    refreshGrid();
    _telemetryTimer = Timer.periodic(telemetryEvery, (_) => refreshTelemetry());
    _gridTimer = Timer.periodic(gridEvery, (_) => refreshGrid());
  }

  void _stopPolling() {
    _telemetryTimer?.cancel();
    _gridTimer?.cancel();
    _telemetryTimer = null;
    _gridTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    if (fg == _foreground) return;
    _foreground = fg;
    if (auth != AuthStatus.signedIn) return;
    if (fg) {
      _startPolling();
    } else {
      _stopPolling(); // the background service takes over
    }
  }

  Future<void> _handleAuthError(ApiException e) async {
    if (e.unauthorized) {
      // Saved password missing or rejected: back to the sign-in screen.
      await logout();
      error = 'Your session ended. Please sign in again.';
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([refreshTelemetry(), refreshGrid(), refreshDevices()]);
  }

  Future<void> refreshTelemetry() async {
    if (auth != AuthStatus.signedIn || refreshing) return;
    refreshing = true;
    notifyListeners();
    ApiException? authError;
    try {
      final t = await api.telemetry();
      telemetry = t;
      lastUpdate = t.timestamp;
      error = null;
      // Alerts come from the background service when it runs (Android); otherwise from here.
      if (!(MonitorService.supported && settings.backgroundMonitoring)) {
        await _alerts.process(t, settings);
      }
      final page = await api.history(HistoryQuery(limit: liveHistoryLimit));
      history = page.data;
      unawaited(WidgetSync.publish(telemetry: t, grid: grid, history: history, threshold: threshold));
    } on ApiException catch (e) {
      error = e.message;
      authError = e;
    } on TimeoutException {
      error = 'The server is slow to answer.';
    } catch (_) {
      error = 'No connection to the server.';
    } finally {
      refreshing = false;
      notifyListeners();
    }
    if (authError != null) await _handleAuthError(authError);
  }

  Future<void> refreshGrid() async {
    if (auth != AuthStatus.signedIn) return;
    try {
      final g = await api.grid();
      if (g == null) {
        gridStatus = LoadStatus.unavailable;
      } else {
        grid = g;
        gridStatus = LoadStatus.ready;
      }
    } catch (_) {
      if (gridStatus != LoadStatus.ready) gridStatus = LoadStatus.error;
    }
    try {
      final f = await api.forecast();
      if (f == null) {
        forecastStatus = LoadStatus.unavailable;
      } else {
        forecast = f;
        forecastStatus = LoadStatus.ready;
      }
    } catch (_) {
      if (forecastStatus != LoadStatus.ready) forecastStatus = LoadStatus.error;
    }
    unawaited(WidgetSync.publish(telemetry: telemetry, grid: grid, forecast: forecast, threshold: threshold));
    notifyListeners();
  }

  Future<void> refreshDevices() async {
    if (auth != AuthStatus.signedIn) return;
    try {
      devices = await api.devices();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> selectDevice(String serial) async {
    try {
      await api.selectDevice(serial);
      await Future.wait([refreshDevices(), refreshTelemetry()]);
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    } catch (_) {}
  }

  Future<HistoryPage> loadHistory(HistoryQuery q) => api.history(q);

  // --- settings ---

  Future<void> setThreshold(int v) async {
    await settings.setBatteryThreshold(v);
    unawaited(WidgetSync.publish(telemetry: telemetry, grid: grid, threshold: v));
    notifyListeners();
  }

  Future<void> setAlarm(bool v) async {
    await settings.setAlarmEnabled(v);
    notifyListeners();
  }

  Future<void> setVoice(bool v) async {
    await settings.setVoiceEnabled(v);
    notifyListeners();
  }

  Future<void> setGridSounds(bool v) async {
    await settings.setGridSoundsEnabled(v);
    notifyListeners();
  }

  Future<void> setBackgroundMonitoring(bool v) async {
    await settings.setBackgroundMonitoring(v);
    if (v) await MonitorService.requestPermissions();
    await _syncBackgroundService();
    notifyListeners();
  }

  /// Changing the server ends the session (tokens belong to one server).
  Future<void> setApiUrl(String url) async {
    final next = Settings.normalizeUrl(url);
    if (next.isEmpty || next == settings.apiUrl) return;
    if (auth == AuthStatus.signedIn) await logout();
    await settings.setApiUrl(next);
    notifyListeners();
  }

  Future<void> testAlarm() async {
    final battery = telemetry?.battery ?? (threshold - 1);
    await _alerts.notifier.lowBattery(battery, threshold, voice: settings.voiceEnabled);
  }

  Future<void> _syncBackgroundService() async {
    if (auth == AuthStatus.signedIn && settings.backgroundMonitoring) {
      await MonitorService.start();
    } else {
      await MonitorService.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }
}

/// Makes [AppState] available to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
