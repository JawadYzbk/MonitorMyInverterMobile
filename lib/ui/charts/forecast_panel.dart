import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../grid.dart';
import '../../models.dart';
import '../theme.dart';
import '../widgets.dart';

const _confidence = {
  'high': ('High confidence', C.battery),
  'medium': ('Medium confidence', C.solar),
  'low': ('Low confidence', C.danger),
  'early': ('Early estimate', C.muted),
};

/// Grid forecast: when power is expected back / off, the next 24 h, the usual
/// daily schedule and summary stats. Port of components/dashboard/GridForecast.tsx.
class ForecastPanel extends StatelessWidget {
  final GridForecast f;
  final DateTime now;

  const ForecastPanel({super.key, required this.f, required this.now});

  @override
  Widget build(BuildContext context) {
    if (f.status == 'learning') {
      final pct = f.neededHours <= 0 ? 0.0 : (f.coverageHours / f.neededHours).clamp(0.0, 1.0);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Learning your grid schedule…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          'The forecast starts after ${f.neededHours.round()} hours of readings. '
          'Collected so far: ${f.coverageHours.round()} hours.',
          style: const TextStyle(fontSize: 13, color: C.muted),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 6, color: C.grid, backgroundColor: C.border),
        ),
      ]);
    }

    final conf = _confidence[f.confidence] ?? _confidence['early']!;
    final st = f.stats;
    final thisWeek = st.hoursPerDayThisWeek, lastWeek = st.hoursPerDayLastWeek;
    final trend = thisWeek != null && lastWeek != null ? thisWeek - lastWeek : null;
    final matchPct = f.patternMatch != null ? (f.patternMatch! * 100).round() : null;

    Widget? trendHint;
    if (trend != null && trend.abs() >= 0.1) {
      final up = trend > 0;
      trendHint = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.trending_up : Icons.trending_down, size: 13, color: up ? C.battery : C.danger),
        const SizedBox(width: 3),
        Flexible(
          child: Text('${formatHours(trend.abs())} vs last week',
              style: TextStyle(fontSize: 11, color: up ? C.battery : C.danger)),
        ),
      ]);
    } else {
      trendHint = Text(lastWeek != null ? 'same as last week' : 'no data for last week yet',
          style: const TextStyle(fontSize: 11, color: C.faint));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _headline(),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _chip(Icons.repeat, [
          Text(f.patternLabel.isEmpty ? 'No clear pattern' : f.patternLabel),
          if (f.patternKind != 'none' && matchPct != null) Text(' · $matchPct% match', style: const TextStyle(color: C.faint)),
        ]),
        _chip(Icons.schedule, [
          Text(f.method == 'pattern' ? 'Based on the repeating pattern' : 'Based on how long cuts usually last'),
        ]),
        _chip(Icons.track_changes, [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: conf.$2, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(conf.$1),
          if (f.accuracyMedianErrorMinutes != null && f.accuracyTested > 0)
            Flexible(
              child: Text(' · within ${f.accuracyMedianErrorMinutes!.round()} min (${f.accuracyTested} past cuts)',
                  style: const TextStyle(color: C.faint)),
            ),
        ]),
      ]),
      const SizedBox(height: 18),
      _nextDayStrip(),
      const SizedBox(height: 18),
      _UsualSchedule(profile: f.profile, nowHour: now.hour),
      const SizedBox(height: 16),
      TwoColumn(children: [
        Fact(label: 'Grid per day (this week)', value: thisWeek != null ? formatHours(thisWeek) : '—', hint: trendHint),
        Fact(
          label: 'Typical cut length',
          value: st.medianOutageMinutes != null
              ? formatDuration(Duration(seconds: (st.medianOutageMinutes! * 60).round()))
              : '—',
        ),
        Fact(
          label: 'Typical on period',
          value: st.medianOnMinutes != null
              ? formatDuration(Duration(seconds: (st.medianOnMinutes! * 60).round()))
              : '—',
        ),
        Fact(
          label: 'Cuts per day',
          value: st.cutsPerDay != null ? _num(st.cutsPerDay!) : '—',
          hint: const Text('last 7 days', style: TextStyle(fontSize: 11, color: C.faint)),
        ),
      ]),
    ]);
  }

  static String _num(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  Widget _headline() {
    final p = f.prediction;
    if (p == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('No forecast right now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          f.currentState != null
              ? "There aren't enough similar past days to predict the next change yet."
              : 'Waiting for a live reading.',
          style: const TextStyle(fontSize: 13, color: C.muted),
        ),
      ]);
    }
    final goingOn = p.state == GridState.on;
    final color = goingOn ? gridOnColor : C.danger;
    const big = TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: C.text);
    final InlineSpan main;
    if (p.overdue) {
      main = TextSpan(style: big, children: [
        const TextSpan(text: 'Grid is '),
        TextSpan(text: goingOn ? 'overdue' : 'usually off by now', style: TextStyle(color: color)),
        if (goingOn) const TextSpan(text: " — it's usually back by now"),
      ]);
    } else {
      main = TextSpan(style: big, children: [
        TextSpan(text: 'Grid expected ${goingOn ? 'back' : 'to go off'} at '),
        TextSpan(text: '${dayWord(p.at, now)}${clock(p.at)}', style: TextStyle(color: color, fontFeatures: tabular)),
        TextSpan(
          text: '  in ${formatDuration(p.at.difference(now))}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: C.muted),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(main),
      const SizedBox(height: 4),
      Text.rich(TextSpan(style: const TextStyle(fontSize: 13, color: C.muted), children: [
        TextSpan(text: 'Likely between ${clock(p.earliest)} and ${clock(p.latest)}'),
        if (f.thenOn != null) ...[
          const TextSpan(text: ' · then back around '),
          TextSpan(text: '${dayWord(f.thenOn!.at, now)}${clock(f.thenOn!.at)}', style: const TextStyle(color: C.text)),
        ],
      ])),
    ]);
  }

  Widget _chip(IconData icon, List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: C.inset,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.border),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 11.5, color: Color(0xFFD4D4D8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: C.faint),
            const SizedBox(width: 5),
            ...children,
          ]),
        ),
      );

  Widget _nextDayStrip() {
    final up = f.upcoming;
    if (up.isEmpty) return const SizedBox.shrink();
    final start = up.first.start;
    final spanMs = up.last.end.difference(start).inMilliseconds;
    if (spanMs <= 0) return const SizedBox.shrink();
    Color color(GridState s) => switch (s) {
          GridState.on => gridOnColor,
          GridState.off => gridOffColor,
          GridState.unknown => noDataColor,
        };
    final onBlocks = up.where((b) => b.state == GridState.on).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionLabel('Expected next 24 hours'),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 26,
          child: Row(children: [
            for (final b in up)
              Expanded(
                flex: (b.end.difference(b.start).inSeconds).clamp(1, 1 << 30),
                child: Container(color: color(b.state)),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < 5; i++)
          Text(i == 0 ? 'now' : clock(start.add(Duration(milliseconds: spanMs * i ~/ 4))),
              style: const TextStyle(fontSize: 10.5, color: C.faint)),
      ]),
      if (onBlocks.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text.rich(TextSpan(style: const TextStyle(fontSize: 12, color: C.muted), children: [
          const TextSpan(text: 'Grid expected: '),
          TextSpan(
            text: onBlocks.map((b) => '${dayWord(b.start, now)}${clock(b.start)}–${clock(b.end)}').join(', '),
            style: const TextStyle(color: Color(0xFFE4E4E7)),
          ),
        ])),
      ],
    ]);
  }
}

/// Chance of grid power for each hour of the day, learned from history.
class _UsualSchedule extends StatelessWidget {
  final List<double?> profile;
  final int nowHour;

  const _UsualSchedule({required this.profile, required this.nowHour});

  @override
  Widget build(BuildContext context) {
    const axis = TextStyle(fontSize: 10.5, color: C.faint);
    final hours = List<double?>.generate(24, (h) => h < profile.length ? profile[h] : null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionLabel('Usual daily schedule · chance of grid each hour'),
      SizedBox(
        height: 140,
        child: BarChart(BarChartData(
          minY: 0,
          maxY: 100,
          alignment: BarChartAlignment.spaceBetween,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var h = 0; h < 24; h++)
              BarChartGroupData(x: h, barRods: [
                BarChartRodData(
                  toY: hours[h] == null ? 0 : (hours[h]! * 100).roundToDouble(),
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  color: hours[h] == null ? noDataColor : gridOnColor.withValues(alpha: 0.35 + 0.65 * hours[h]!),
                  borderSide: h == nowHour ? const BorderSide(color: C.text, width: 1.5) : BorderSide.none,
                ),
              ]),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 50,
                getTitlesWidget: (v, _) => Text('${v.round()}%', style: axis),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (v, _) {
                  final h = v.round();
                  if (h % 3 != 0) return const SizedBox();
                  return Padding(
                      padding: const EdgeInsets.only(top: 4), child: Text(h.toString().padLeft(2, '0'), style: axis));
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => C.bg,
              tooltipBorder: const BorderSide(color: C.border),
              fitInsideHorizontally: true,
              getTooltipItem: (group, _, rod, _) {
                final h = group.x;
                final range = '${h.toString().padLeft(2, '0')}:00–${((h + 1) % 24).toString().padLeft(2, '0')}:00';
                final p = hours[h];
                return BarTooltipItem(
                  '$range · ${p == null ? 'no data yet' : 'grid on ${(p * 100).round()}% of the time'}',
                  const TextStyle(color: C.text, fontSize: 12),
                );
              },
            ),
          ),
        )),
      ),
      const SizedBox(height: 4),
      const Text('Outlined bar = current hour. Recent days count more.', style: TextStyle(fontSize: 10.5, color: C.faint)),
    ]);
  }
}
