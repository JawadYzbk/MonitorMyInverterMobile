import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../grid.dart';
import '../theme.dart';
import '../widgets.dart';

class GridLegend extends StatelessWidget {
  const GridLegend({super.key});

  @override
  Widget build(BuildContext context) =>
      const Legend(items: [('Grid on', gridOnColor), ('Grid off', gridOffColor), ('No data', noDataColor)]);
}

/// Last 24 hours: one stacked bar per hour (minutes on / off / no data).
class GridDayChart extends StatelessWidget {
  final List<HourBucket> buckets;
  final DateTime now;

  const GridDayChart({super.key, required this.buckets, required this.now});

  @override
  Widget build(BuildContext context) {
    const axis = TextStyle(fontSize: 10.5, color: C.faint);
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final on = (b.on / 60).roundToDouble();
      final off = (b.off / 60).roundToDouble();
      final isCurrent = i == buckets.length - 1;
      final elapsed =
          isCurrent ? (now.difference(b.start).inSeconds / 60).round().clamp(0, 60).toDouble() : 60.0;
      final none = (elapsed - on - off).clamp(0, 60).toDouble();
      final total = on + off + none;
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: total,
          width: 8,
          color: Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          rodStackItems: [
            BarChartRodStackItem(0, on, gridOnColor),
            BarChartRodStackItem(on, on + off, gridOffColor),
            BarChartRodStackItem(on + off, total, noDataColor),
          ],
        ),
      ]));
    }

    return SizedBox(
      height: 170,
      child: BarChart(
        BarChartData(
          maxY: 60,
          minY: 0,
          alignment: BarChartAlignment.spaceBetween,
          barGroups: groups,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 30,
                getTitlesWidget: (v, _) => Text('${v.round()}m', style: axis),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final i = v.round();
                  if (i % 4 != 0 || i >= buckets.length) return const SizedBox();
                  return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(clock(buckets[i].start), style: axis));
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => C.bg,
              tooltipBorder: const BorderSide(color: C.border),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, _, _, _) => BarTooltipItem(
                describeHour(buckets[group.x]),
                const TextStyle(color: C.text, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Last 7 days, hour by hour: rows are days, columns are hours. Tap a cell for details.
class GridWeekHeatmap extends StatefulWidget {
  final List<List<HourBucket>> days;
  final DateTime now;

  const GridWeekHeatmap({super.key, required this.days, required this.now});

  @override
  State<GridWeekHeatmap> createState() => _GridWeekHeatmapState();
}

class _GridWeekHeatmapState extends State<GridWeekHeatmap> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 11, color: C.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < widget.days.length; r++) ...[
          _row(r),
          const SizedBox(height: 4),
        ],
        Row(children: [
          const SizedBox(width: 42),
          Expanded(
            child: Row(children: [
              for (var h = 0; h < 24; h++)
                Expanded(
                  child: Text(h % 6 == 0 ? h.toString().padLeft(2, '0') : '',
                      softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 10, color: C.faint)),
                ),
            ]),
          ),
          const SizedBox(width: 56, child: Text('on / day', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: C.faint))),
        ]),
        const SizedBox(height: 10),
        Text(_selected ?? 'Tap a cell to see that hour.', style: label),
      ],
    );
  }

  Widget _row(int r) {
    final row = widget.days[r];
    final isToday = r == widget.days.length - 1;
    return Row(children: [
      SizedBox(
        width: 42,
        child: Text(isToday ? 'Today' : weekday(row.first.start),
            style: TextStyle(
                fontSize: 11.5,
                color: isToday ? C.text : C.muted,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.normal)),
      ),
      Expanded(
        child: Row(children: [
          for (final b in row)
            Expanded(
              child: GestureDetector(
                onTap: b.start.isAfter(widget.now)
                    ? null
                    : () => setState(() => _selected = '${weekday(b.start)} ${describeHour(b)}'),
                child: Container(
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: b.start.isAfter(widget.now) ? Colors.transparent : gridCellColor(b),
                    borderRadius: BorderRadius.circular(3),
                    border: b.start.isAfter(widget.now) ? Border.all(color: C.border, width: 0.8) : null,
                  ),
                ),
              ),
            ),
        ]),
      ),
      SizedBox(
        width: 56,
        child: Text(hasData(row) ? formatHours(totalOnHours(row)) : '—',
            textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: C.text, fontFeatures: tabular)),
      ),
    ]);
  }
}
