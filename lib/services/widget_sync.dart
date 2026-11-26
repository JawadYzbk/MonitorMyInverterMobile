import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../grid.dart';
import '../models.dart';
import 'api.dart';
import 'settings.dart';

/// Feeds the Android home screen widgets (android_overlay/.../widgets/*.kt).
///
/// Everything is stored as strings under `w_*` keys; the Kotlin side formats
/// times ("since 14:20 · 2h 5m", "in 45m") when it draws, so they stay right
/// between updates.
class WidgetSync {
  static const _pkg = 'app.wattwise.wattwise.widgets';
  static const providers = [
    'BatteryWidget',
    'GridWidget',
    'PowerWidget',
    'OverviewWidget',
    'ForecastWidget',
    'TrendWidget',
  ];

  /// Widgets exist on Android only (iPhone widgets would need a Swift WidgetKit
  /// extension and App Groups, which free Apple accounts don't get).
  static bool get supported => Platform.isAndroid;

  static String _ms(DateTime? t) => t == null ? '' : '${t.millisecondsSinceEpoch}';

  static String _n(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  static String _w(double v) =>
      v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  /// Saves whatever is given and redraws all widgets. Never throws.
  static Future<void> publish({
    Telemetry? telemetry,
    GridResponse? grid,
    GridForecast? forecast,
    List<HistoryLog>? history,
    int? threshold,
  }) async {
    if (!supported) return;
    try {
      final w = <String, String>{};
      final now = DateTime.now();

      if (threshold != null) w['w_threshold'] = '$threshold';

      final t = telemetry;
      if (t != null) {
        final th = threshold ?? 25;
        final charging = t.batteryChargingCurrent > 0;
        final using = t.batteryDischargingCurrent > 0;
        w['w_battery'] = '${t.battery}';
        w['w_low'] = t.battery < th ? '1' : '0';
        w['w_batt_flow'] = charging
            ? 'charging ${_n(t.batteryChargingCurrent)} A'
            : using
                ? 'using ${_n(t.batteryDischargingCurrent)} A'
                : 'idle';
        w['w_batt_volts'] = '${_n(t.batteryVoltage)} V';
        w['w_solar'] = _w(t.pvInputPower);
        w['w_pv_volts'] = '${_n(t.pvVoltage)} V';
        w['w_load'] = _w(t.loadPower);
        w['w_load_pct'] = '${_n(t.loadPercent)}%';
        final net = t.pvInputPower - t.loadPower;
        w['w_net'] = net >= 0 ? '+${_w(net)} W spare' : '${_w(-net)} W from battery/grid';
        w['w_net_sign'] = net >= 0 ? '1' : '-1';
        final gridThreshold = grid?.threshold ?? defaultGridOnVoltage;
        w['w_grid'] = !t.online ? 'unknown' : (t.acInputVoltage >= gridThreshold ? 'on' : 'off');
        w['w_grid_volts'] = '${_n(t.acInputVoltage)} V';
        w['w_online'] = t.online ? '1' : '0';
        w['w_updated'] = _ms(t.timestamp ?? now);
      }

      if (grid != null) {
        w['w_grid_since'] = _ms(grid.lastChange);
        final day = last24Hours(grid.segments, now);
        w['w_past24'] = day.map((b) {
          final f = onFraction(b);
          return f == null ? '-1' : '${(f * 100).round()}';
        }).join(',');
        w['w_past24_start'] = _ms(day.first.start);
        final week = last7Days(grid.segments, now);
        w['w_today_on'] = formatHours(totalOnHours(week.last));
        w['w_cuts24'] = '${countOutages(grid.segments, now.subtract(const Duration(hours: 24)))}';
      }

      if (forecast != null) {
        final f = forecast;
        w['w_fc_status'] = f.status;
        w['w_fc_learning'] = f.neededHours <= 0
            ? ''
            : 'Learning your grid schedule · ${(f.coverageHours / f.neededHours * 100).clamp(0, 100).round()}%';
        final p = f.prediction;
        w['w_fc_state'] = p == null ? '' : p.state.name;
        w['w_fc_at'] = _ms(p?.at);
        w['w_fc_earliest'] = _ms(p?.earliest);
        w['w_fc_latest'] = _ms(p?.latest);
        w['w_fc_overdue'] = p?.overdue == true ? '1' : '0';
        w['w_fc_then_on'] = _ms(f.thenOn?.at);
        w['w_fc_conf'] = switch (f.confidence) {
          'high' => 'High confidence',
          'medium' => 'Medium confidence',
          'low' => 'Low confidence',
          _ => 'Early estimate',
        };
        w['w_next24'] =
            f.upcoming.map((b) => '${b.state.name}:${b.end.difference(b.start).inMinutes.clamp(1, 1 << 20)}').join(',');
        w['w_next24_start'] = f.upcoming.isEmpty ? '' : _ms(f.upcoming.first.start);
      }

      if (history != null && history.isNotEmpty) {
        final rows = [...history]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final end = rows.last.timestamp;
        final start = end.subtract(const Duration(hours: 4));
        final recent = rows.where((r) => !r.timestamp.isBefore(start)).toList();
        // Down-sample to at most 60 points so the bitmap stays small.
        final step = (recent.length / 60).ceil().clamp(1, 1 << 20);
        final pts = [for (var i = 0; i < recent.length; i += step) recent[i]];
        if (pts.last != recent.last) pts.add(recent.last);
        w['w_trend_batt'] = pts.map((r) => r.batteryCapacity.round()).join(',');
        w['w_trend_solar'] = pts.map((r) => r.pvInputPower.round()).join(',');
        w['w_trend_load'] = pts.map((r) => r.loadPower.round()).join(',');
        w['w_trend_start'] = _ms(pts.first.timestamp);
        w['w_trend_end'] = _ms(pts.last.timestamp);
        // Battery change over the last hour.
        final hourAgo = end.subtract(const Duration(hours: 1));
        final older = rows.lastWhere((r) => !r.timestamp.isAfter(hourAgo), orElse: () => rows.first);
        final mins = end.difference(older.timestamp).inMinutes;
        if (mins >= 20) {
          final perHour = (rows.last.batteryCapacity - older.batteryCapacity) * 60 / mins;
          final r = perHour.round();
          w['w_trend_rate'] = r == 0 ? 'Battery steady' : 'Battery ${r > 0 ? '+' : '−'}${r.abs()}% per hour';
        } else {
          w['w_trend_rate'] = '';
        }
      }

      for (final e in w.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await redraw();
    } catch (e) {
      debugPrint('WidgetSync.publish failed: $e');
    }
  }

  static Future<void> redraw() async {
    if (!supported) return;
    for (final p in providers) {
      try {
        await HomeWidget.updateWidget(qualifiedAndroidName: '$_pkg.$p');
      } catch (_) {}
    }
  }

  /// Marks the widgets as signed out (shown until the next sign-in).
  static Future<void> signedOut() async {
    if (!supported) return;
    try {
      await HomeWidget.saveWidgetData<String>('w_online', '0');
      await HomeWidget.saveWidgetData<String>('w_updated', '');
      await redraw();
    } catch (_) {}
  }

  /// Fetches everything the widgets show and publishes it (used by the widget
  /// refresh button and the background service).
  static Future<void> fetchAndPublish(Settings s, ShineApi api, {bool full = true}) async {
    final t = await api.telemetry();
    GridResponse? grid;
    GridForecast? forecast;
    List<HistoryLog>? history;
    if (full) {
      final results = await Future.wait<Object?>([
        api.grid().catchError((_) => null),
        api.forecast().catchError((_) => null),
        api.history(HistoryQuery(limit: 240)).then<Object?>((p) => p.data).catchError((_) => null),
      ]);
      grid = results[0] as GridResponse?;
      forecast = results[1] as GridForecast?;
      history = results[2] as List<HistoryLog>?;
    }
    await publish(
      telemetry: t,
      grid: grid,
      forecast: forecast,
      history: history,
      threshold: s.batteryThreshold,
    );
  }
}

/// Called by the widget refresh button (runs in a background isolate).
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (uri?.host != 'refresh') return;
  try {
    final s = await Settings.load();
    if (s.token == null) return;
    await WidgetSync.fetchAndPublish(s, ShineApi(s));
  } catch (_) {
    await WidgetSync.redraw();
  }
}
