import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App settings. There is deliberately no built-in server address: the user
/// enters their own gateway on the sign-in screen and it stays on the phone.
/// Plain values live in SharedPreferences (readable from the
/// background service isolate); the password lives in the Android keystore.
class Settings {
  static const _kApiUrl = 'api_url';
  static const _kUser = 'username';
  static const _kToken = 'token';
  static const _kRemember = 'remember';
  static const _kThreshold = 'battery_threshold';
  static const _kAlarm = 'alarm_enabled';
  static const _kGridSounds = 'grid_sounds_enabled';
  static const _kVoice = 'voice_enabled';
  static const _kBackground = 'background_monitoring';
  static const _kPass = 'password';

  static const _secure = FlutterSecureStorage();

  final SharedPreferences prefs;
  Settings._(this.prefs);

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  /// Picks up values written by the other isolate (UI vs background service).
  Future<void> reload() => prefs.reload();

  /// The user's gateway, or "" until they enter one.
  String get apiUrl => prefs.getString(_kApiUrl) ?? '';
  bool get hasServer => apiUrl.isNotEmpty;
  Future<void> setApiUrl(String v) => prefs.setString(_kApiUrl, normalizeUrl(v));

  String get username => prefs.getString(_kUser) ?? '';
  Future<void> setUsername(String v) => prefs.setString(_kUser, v);

  String? get token => prefs.getString(_kToken);
  Future<void> setToken(String? v) => v == null ? prefs.remove(_kToken) : prefs.setString(_kToken, v);

  bool get remember => prefs.getBool(_kRemember) ?? true;
  Future<void> setRemember(bool v) => prefs.setBool(_kRemember, v);

  int get batteryThreshold => prefs.getInt(_kThreshold) ?? 25;
  Future<void> setBatteryThreshold(int v) => prefs.setInt(_kThreshold, v.clamp(0, 100));

  bool get alarmEnabled => prefs.getBool(_kAlarm) ?? true;
  Future<void> setAlarmEnabled(bool v) => prefs.setBool(_kAlarm, v);

  bool get gridSoundsEnabled => prefs.getBool(_kGridSounds) ?? true;
  Future<void> setGridSoundsEnabled(bool v) => prefs.setBool(_kGridSounds, v);

  bool get voiceEnabled => prefs.getBool(_kVoice) ?? true;
  Future<void> setVoiceEnabled(bool v) => prefs.setBool(_kVoice, v);

  bool get backgroundMonitoring => prefs.getBool(_kBackground) ?? true;
  Future<void> setBackgroundMonitoring(bool v) => prefs.setBool(_kBackground, v);

  Future<String?> readPassword() async {
    try {
      return await _secure.read(key: _kPass);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePassword(String? v) async {
    try {
      if (v == null) {
        await _secure.delete(key: _kPass);
      } else {
        await _secure.write(key: _kPass, value: v);
      }
    } catch (_) {}
  }

  Future<void> clearSession() async {
    await setToken(null);
    await savePassword(null);
  }

  /// Adds a scheme if missing: http:// for local addresses (IP, localhost,
  /// host:port on the LAN), https:// for everything else. "" stays "".
  static String normalizeUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return '';
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      final host = u.split('/').first.split(':').first;
      final local = host == 'localhost' ||
          RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) ||
          host.endsWith('.local') ||
          !host.contains('.');
      u = (local ? 'http://' : 'https://') + u;
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
