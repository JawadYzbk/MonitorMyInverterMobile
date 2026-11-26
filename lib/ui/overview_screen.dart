import 'dart:async';

import 'package:flutter/material.dart';

import '../grid.dart';
import '../state/app_state.dart';
import 'charts/forecast_panel.dart';
import 'charts/grid_charts.dart';
import 'charts/power_chart.dart';
import 'theme.dart';
import 'widgets.dart';

/// Port of app/(dashboard)/dashboard/page.tsx.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _alertDismissed = false;
  bool _wasLow = false;
  Timer? _minute;

  @override
  void initState() {
    super.initState();
    // Re-render each minute so "since" times and the current hour stay fresh.
    _minute = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }

  static String _w(double v) {
    final s = v.round().toString();
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  static String _n(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = s.telemetry;
    final now = DateTime.now();
    final threshold = s.threshold;

    final battery = d?.battery ?? 0;
    final isLow = d != null && battery < threshold;
    // Show the alert again the next time the battery drops below the threshold.
    if (_wasLow != isLow) {
      _wasLow = isLow;
      if (!isLow) _alertDismissed = false;
    }

    // --- grid ---
    final grid = s.grid;
    final gridThreshold = grid?.threshold ?? defaultGridOnVoltage;
    final gridVoltage = d?.acInputVoltage ?? 0;
    final gridOn = gridVoltage >= gridThreshold;
    final live = d?.online ?? false;
    final segments = grid?.segments ?? const [];
    final day = last24Hours(segments, now);
    final week = last7Days(segments, now);
    final daysWithData = week.where(hasData).toList();
    final avgPerDay =
        daysWithData.isEmpty ? 0.0 : daysWithData.fold<double>(0, (a, r) => a + totalOnHours(r)) / daysWithData.length;
    final outages24h = countOutages(segments, now.subtract(const Duration(hours: 24)));
    final lastChange = grid?.lastChange;
    final since = lastChange != null ? 'since ${clock(lastChange)} · ${formatDuration(now.difference(lastChange))}' : null;
    final p = s.forecast?.prediction;
    final next = p != null && !p.overdue ? '${p.state.name == 'on' ? 'back' : 'off'} ~${clock(p.at)}' : null;

    // --- battery ---
    final charging = (d?.batteryChargingCurrent ?? 0) > 0;
    final discharging = (d?.batteryDischargingCurrent ?? 0) > 0;
    final batteryDetail = '${_n(d?.batteryVoltage ?? 0)} V · ${charging ? 'charging ${_n(d!.batteryChargingCurrent)} A' : discharging ? 'using ${_n(d!.batteryDischargingCurrent)} A' : 'idle'}';
    final batteryColor = isLow ? C.danger : C.battery;

    return RefreshIndicator(
      onRefresh: s.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        children: [
          if (s.error != null && d == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(s.error!, style: const TextStyle(color: C.danger, fontSize: 13)),
            ),
          if (isLow && !_alertDismissed) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              decoration: BoxDecoration(
                color: C.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.danger.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: C.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(TextSpan(style: const TextStyle(fontSize: 13, color: C.text), children: [
                    TextSpan(
                        text: 'Battery low: $battery%. ',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFFCA5A5))),
                    TextSpan(text: 'It is below your $threshold% alert level. Reduce the load if you can.'),
                  ])),
                ),
                IconButton(
                  tooltip: 'Dismiss alert',
                  onPressed: () => setState(() => _alertDismissed = true),
                  icon: const Icon(Icons.close, size: 18, color: C.muted),
                ),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          TwoColumn(children: [
            StatTile(
              icon: charging ? Icons.battery_charging_full : Icons.battery_5_bar,
              label: 'Battery',
              value: '$battery',
              unit: '%',
              detail: batteryDetail,
              accent: batteryColor,
              extra: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (battery.clamp(0, 100)) / 100),
                    duration: const Duration(milliseconds: 700),
                    builder: (_, v, _) =>
                        LinearProgressIndicator(value: v, minHeight: 6, color: batteryColor, backgroundColor: C.border),
                  ),
                ),
              ),
            ),
            StatTile(
              icon: Icons.electrical_services,
              label: 'Grid power',
              value: d == null ? '—' : (gridOn ? 'On' : 'Off'),
              detail: d == null
                  ? 'No reading yet'
                  : live
                      ? '${_n(gridVoltage)} V${since != null ? ' · $since' : ''}${next != null ? ' · $next' : ''}'
                      : '${_n(gridVoltage)} V · not live',
              accent: !live ? C.muted : (gridOn ? C.grid : C.danger),
            ),
            StatTile(
              icon: Icons.wb_sunny_outlined,
              label: 'Solar',
              value: _w(d?.pvInputPower ?? 0),
              unit: 'W',
              detail: 'Panels at ${_n(d?.pvVoltage ?? 0)} V',
              accent: C.solar,
            ),
            StatTile(
              icon: Icons.speed,
              label: 'Home load',
              value: _w(d?.loadPower ?? 0),
              unit: 'W',
              detail: '${_n(d?.loadPercent ?? 0)}% of inverter capacity',
              accent: C.load,
            ),
          ]),
          const SizedBox(height: 14),
          Panel(
            title: 'Grid forecast',
            child: s.forecastStatus == LoadStatus.ready && s.forecast != null
                ? ForecastPanel(f: s.forecast!, now: now)
                : Placeholder2(switch (s.forecastStatus) {
                    LoadStatus.loading => 'Analysing grid history…',
                    LoadStatus.unavailable => 'The forecast needs the latest backend. Deploy it to see predictions.',
                    _ => "Couldn't load the forecast. It will retry in a moment.",
                  }),
          ),
          const SizedBox(height: 14),
          Panel(title: 'Power', child: PowerChart(history: s.history)),
          const SizedBox(height: 14),
          Panel(
            title: 'Grid power',
            action: const GridLegend(),
            child: s.gridStatus == LoadStatus.ready
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TwoColumn(children: [
                      Fact(label: 'Today', value: formatHours(totalOnHours(week[6]))),
                      Fact(label: 'Last 24 hours', value: formatHours(totalOnHours(day))),
                      Fact(label: 'Daily average (7 days)', value: formatHours(avgPerDay)),
                      Fact(label: 'Cuts in last 24 hours', value: '$outages24h'),
                    ]),
                    const SizedBox(height: 20),
                    const SectionLabel('Last 24 hours · minutes of grid power per hour'),
                    GridDayChart(buckets: day, now: now),
                    const SizedBox(height: 20),
                    const SectionLabel('Last 7 days · hour by hour'),
                    GridWeekHeatmap(days: week, now: now),
                  ])
                : Placeholder2(switch (s.gridStatus) {
                    LoadStatus.loading => 'Loading grid history…',
                    LoadStatus.unavailable =>
                      'Grid history needs the latest backend. Deploy it to start seeing these charts.',
                    _ => "Couldn't load grid history. It will retry in a moment.",
                  }),
          ),
        ],
      ),
    );
  }
}
