import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'settings.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);

  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}

/// Thin client for the MonitorMyInverter gateway. Sends the session token as a
/// Bearer header and, like the Windows tray app, logs in again silently with the
/// saved credentials when the server forgets the session.
class ShineApi {
  final Settings settings;
  final http.Client _http;

  /// Render free instances can take close to a minute to wake up.
  static const timeout = Duration(seconds: 60);

  ShineApi(this.settings, [http.Client? client]) : _http = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Settings.normalizeUrl(settings.apiUrl);
    if (base.isEmpty) throw ApiException('Enter your server address first.');
    return Uri.parse('$base$path').replace(queryParameters: query?.isEmpty ?? true ? null : query);
  }

  Map<String, String> _headers({bool json = false}) => {
        if (settings.token != null) 'Authorization': 'Bearer ${settings.token}',
        if (json) 'Content-Type': 'application/json',
      };

  static String _detail(http.Response r) {
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['detail'] != null) return body['detail'].toString();
    } catch (_) {}
    return 'Request failed (${r.statusCode}).';
  }

  static ApiException _error(http.Response r) {
    final detail = _detail(r);
    // /api/telemetry wraps its 401 in a 500 ("401: Unauthorized session.").
    final unauthorized = r.statusCode == 401 || detail.startsWith('401');
    return ApiException(detail, unauthorized ? 401 : r.statusCode);
  }

  /// POST /api/auth/login — returns the session token and stores it.
  Future<String> login(String username, String password) async {
    final r = await _http
        .post(_uri('/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}))
        .timeout(timeout);
    if (r.statusCode != 200) throw _error(r);
    final token = (jsonDecode(r.body) as Map)['token'] as String;
    await settings.setToken(token);
    return token;
  }

  Future<void> logout() async {
    try {
      await _http.post(_uri('/api/auth/logout'), headers: _headers()).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<bool> _relogin() async {
    final user = settings.username;
    final pass = await settings.readPassword();
    if (user.isEmpty || pass == null || pass.isEmpty) return false;
    try {
      await login(user, pass);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _send(Future<http.Response> Function() call, {bool allow404 = false}) async {
    var r = await call().timeout(timeout);
    if (r.statusCode == 200) return jsonDecode(r.body);
    var err = _error(r);
    if (err.unauthorized && await _relogin()) {
      r = await call().timeout(timeout);
      if (r.statusCode == 200) return jsonDecode(r.body);
      err = _error(r);
    }
    if (allow404 && r.statusCode == 404) return null;
    throw err;
  }

  Future<dynamic> _get(String path, [Map<String, String>? query, bool allow404 = false]) =>
      _send(() => _http.get(_uri(path, query), headers: _headers()), allow404: allow404);

  Future<Telemetry> telemetry() async =>
      Telemetry.fromJson(Map<String, dynamic>.from(await _get('/api/telemetry') as Map));

  Future<HistoryPage> history(HistoryQuery q) async => HistoryPage.fromJson(await _get('/api/history', q.toParams()));

  Future<List<Device>> devices() async {
    final list = await _get('/api/devices') as List;
    return list.map((e) => Device.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> selectDevice(String serial) async {
    await _send(() => _http.post(_uri('/api/devices/select'),
        headers: _headers(json: true), body: jsonEncode({'serial_number': serial})));
  }

  /// null when the backend has no /api/grid yet (404).
  Future<GridResponse?> grid({int hours = 24 * 7}) async {
    final j = await _get('/api/grid', {'hours': '$hours'}, true);
    return j == null ? null : GridResponse.fromJson(Map<String, dynamic>.from(j));
  }

  /// null when the backend has no forecast endpoint yet (404).
  Future<GridForecast?> forecast() async {
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    final j = await _get('/api/grid/forecast', {'tz_offset': '$offset'}, true);
    return j == null ? null : GridForecast.fromJson(Map<String, dynamic>.from(j));
  }
}
