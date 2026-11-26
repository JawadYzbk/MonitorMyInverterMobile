import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../grid.dart' show clock;
import '../../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Load and solar (W) with battery (%) over the last 1 / 2 / 4 hours.
/// Port of components/dashboard/PowerChart.tsx.
class PowerChart extends StatefulWidget {
  final List<HistoryLog> history;
  const PowerChart({super.key, required this.history});

  @override
  State<PowerChart> createState() => _PowerChartState();
}

class _PowerChartState extends State<PowerChart> {
  static const _ranges = {'1 h': 1, '2 h': 2, '4 h': 4};
  String _range = '2 h';

  @override
  Widget build(BuildContext context) {
    final hours = _ranges[_range]!;
    final rows = [...widget.history]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final latest = rows.isEmpty ? 0 : rows.last.timestamp.millisecondsSinceEpoch;
    final data = rows.where((r) => latest - r.timestamp.millisecondsSinceEpoch <= hours * 3600000).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            const Legend(square: false, items: [('Load W', C.load), ('Solar W', C.solar), ('Battery %', C.battery)]),
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12),
                selectedBackgroundColor: C.border,
                side: const BorderSide(color: C.border),
              ),
              segments: [for (final k in _ranges.keys) ButtonSegment(value: k, label: Text(k))],
              selected: {_range},
              onSelectionChanged: (v) => setState(() => _range = v.first),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 230,
          child: data.length < 2
              ? const Center(child: Text('Waiting for data…', style: TextStyle(color: C.faint, fontSize: 13)))
              : _chart(data),
        ),
      ],
    );
  }

  Widget _chart(List<HistoryLog> data) {
    final maxW = data.fold<double>(0, (m, r) => math.max(m, math.max(r.loadPower, r.pvInputPower)));
    final top = _niceCeil(math.max(maxW * 1.1, 100));
    double x(HistoryLog r) => r.timestamp.millisecondsSinceEpoch.toDouble();
    final minX = x(data.first), maxX = x(data.last);
    final span = math.max(maxX - minX, 60000.0);

    LineChartBarData area(List<FlSpot> spots, Color color) => LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
            ),
          ),
        );

    final solar = area([for (final r in data) FlSpot(x(r), r.pvInputPower)], C.solar);
    final load = area([for (final r in data) FlSpot(x(r), r.loadPower)], C.load);
    // Battery % is drawn on the watt scale and labelled on the right axis.
    final battery = LineChartBarData(
      spots: [for (final r in data) FlSpot(x(r), r.batteryCapacity.clamp(0, 100) / 100 * top)],
      isCurved: true,
      preventCurveOverShooting: true,
      color: C.battery,
      barWidth: 1.5,
      dashArray: [4, 3],
      dotData: const FlDotData(show: false),
    );

    const axis = TextStyle(fontSize: 10.5, color: C.faint);
    const names = ['Solar', 'Load', 'Battery'];
    const colors = [C.solar, C.load, C.battery];
    return LineChart(
      LineChartData(
        minX: minX,
        maxX: minX + span,
        minY: 0,
        maxY: top,
        lineBarsData: [solar, load, battery],
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: top / 4,
          getDrawingHorizontalLine: (_) => const FlLine(color: C.border, strokeWidth: 1, dashArray: [3, 3]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: top / 4,
              getTitlesWidget: (v, meta) => Text(_watts(v), style: axis),
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: top / 2,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('${(v / top * 100).round()}%', style: axis),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: span / 3,
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(clock(DateTime.fromMillisecondsSinceEpoch(v.round())), style: axis),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => C.bg,
            tooltipBorder: const BorderSide(color: C.border),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (var i = 0; i < spots.length; i++)
                LineTooltipItem(
                  '${i == 0 ? '${clock(DateTime.fromMillisecondsSinceEpoch(spots[i].x.round()))}\n' : ''}'
                  '${names[spots[i].barIndex]}  '
                  '${spots[i].barIndex == 2 ? '${(spots[i].y / top * 100).round()}%' : '${spots[i].y.round()} W'}',
                  TextStyle(color: colors[spots[i].barIndex], fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static double _niceCeil(double v) {
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final step in [1, 2, 2.5, 5, 10]) {
      if (step * mag >= v) return step * mag;
    }
    return 10 * mag;
  }

  static String _watts(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k' : '${v.round()}';
}
