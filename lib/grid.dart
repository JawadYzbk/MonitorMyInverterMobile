// Grid (utility power) availability maths. Port of MonitorMyInverter-frontend/lib/grid.ts.
import 'dart:ui' show Color;

import 'models.dart';

const hourMs = 3600000;

/// Keep in sync with GRID_ON_VOLTAGE in the backend (used until /api/grid answers).
const defaultGridOnVoltage = 100.0;

/// One local-time hour: seconds with grid on / off. The rest of the hour had no data.
class HourBucket {
  final DateTime start;
  double on = 0;
  double off = 0;

  HourBucket(this.start);
}

List<HourBucket> bucketHours(List<GridSegment> segments, DateTime start, int hours) {
  final startMs = start.millisecondsSinceEpoch;
  final endMs = startMs + hours * hourMs;
  final buckets = List.generate(hours, (i) => HourBucket(DateTime.fromMillisecondsSinceEpoch(startMs + i * hourMs)));
  for (final seg in segments) {
    if (seg.state == GridState.unknown) continue;
    var s = seg.start.millisecondsSinceEpoch;
    final e = seg.end.millisecondsSinceEpoch < endMs ? seg.end.millisecondsSinceEpoch : endMs;
    if (e <= startMs || s >= endMs) continue;
    if (s < startMs) s = startMs;
    var idx = (s - startMs) ~/ hourMs;
    while (s < e && idx < hours) {
      final chunkEnd = e < startMs + (idx + 1) * hourMs ? e : startMs + (idx + 1) * hourMs;
      final secs = (chunkEnd - s) / 1000;
      if (seg.state == GridState.on) {
        buckets[idx].on += secs;
      } else {
        buckets[idx].off += secs;
      }
      s = chunkEnd;
      idx += 1;
    }
  }
  return buckets;
}

DateTime _hourFloor(DateTime now) => DateTime(now.year, now.month, now.day, now.hour);

/// 24 buckets ending with the current (partial) local hour.
List<HourBucket> last24Hours(List<GridSegment> segments, DateTime now) {
  final top = _hourFloor(now);
  return bucketHours(segments, top.subtract(const Duration(hours: 23)), 24);
}

/// 7 rows (oldest first) of 24 local hours; the last row is today.
List<List<HourBucket>> last7Days(List<GridSegment> segments, DateTime now) {
  return List.generate(7, (i) {
    final day = DateTime(now.year, now.month, now.day - (6 - i));
    return bucketHours(segments, day, 24);
  });
}

/// Share of the covered part of the hour with grid power, or null if no data.
double? onFraction(HourBucket b) {
  final covered = b.on + b.off;
  return covered < 60 ? null : b.on / covered;
}

bool hasData(List<HourBucket> buckets) => buckets.any((b) => onFraction(b) != null);

double totalOnHours(List<HourBucket> buckets) => buckets.fold<double>(0, (sum, b) => sum + b.on) / 3600;

/// Number of times grid power went off since [from].
int countOutages(List<GridSegment> segments, DateTime from) {
  var count = 0;
  for (var i = 1; i < segments.length; i++) {
    final seg = segments[i];
    if (seg.state == GridState.off && segments[i - 1].state == GridState.on && !seg.start.isBefore(from)) {
      count += 1;
    }
  }
  return count;
}

String formatHours(double hours) {
  var h = hours.floor();
  var m = ((hours - h) * 60).round();
  if (m == 60) {
    h += 1;
    m = 0;
  }
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

String formatDuration(Duration d) {
  final totalMin = d.inMinutes < 0 ? 0 : d.inMinutes;
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

String clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String weekday(DateTime t) => _weekdays[t.weekday - 1];

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "" for today, "tomorrow " or "Wed " otherwise.
String dayWord(DateTime t, DateTime now) {
  if (_sameDay(t, now)) return '';
  if (_sameDay(t, now.add(const Duration(days: 1)))) return 'tomorrow ';
  return '${weekday(t)} ';
}

// Colors shared by the grid charts.
const gridOnColor = Color(0xFF38BDF8); // sky-400
const gridOffColor = Color(0xFF5B2A30);
const noDataColor = Color(0xFF27272A); // zinc-800

Color gridCellColor(HourBucket b) {
  final f = onFraction(b);
  if (f == null) return noDataColor;
  int mix(int a, int b) => (a + (b - a) * f).round();
  return Color.fromARGB(255, mix(0x5B, 0x38), mix(0x2A, 0xBD), mix(0x30, 0xF8));
}

String describeHour(HourBucket b) {
  final end = b.start.add(const Duration(hours: 1));
  final range = '${clock(b.start)}–${clock(end)}';
  if (onFraction(b) == null) return '$range · no data';
  final on = (b.on / 60).round();
  final off = (b.off / 60).round();
  return '$range · $on min on${off > 0 ? ', $off min off' : ''}';
}
