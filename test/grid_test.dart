import 'package:flutter_test/flutter_test.dart';
import 'package:piq6_monitor/grid.dart';
import 'package:piq6_monitor/models.dart';

GridSegment seg(DateTime s, DateTime e, GridState st) => GridSegment(s, e, st);

void main() {
  final base = DateTime(2026, 11, 20, 10); // local 10:00

  group('bucketHours', () {
    test('splits a segment across hour boundaries', () {
      final segs = [seg(base.add(const Duration(minutes: 30)), base.add(const Duration(minutes: 90)), GridState.on)];
      final b = bucketHours(segs, base, 3);
      expect(b[0].on, 30 * 60);
      expect(b[1].on, 30 * 60);
      expect(b[2].on, 0);
      expect(b[0].off, 0);
    });

    test('clips segments outside the window', () {
      final segs = [
        seg(base.subtract(const Duration(hours: 2)), base.add(const Duration(minutes: 15)), GridState.off),
        seg(base.add(const Duration(hours: 1, minutes: 45)), base.add(const Duration(hours: 5)), GridState.on),
      ];
      final b = bucketHours(segs, base, 2);
      expect(b[0].off, 15 * 60);
      expect(b[1].on, 15 * 60);
    });
  });

  test('onFraction needs at least a minute of data', () {
    final b = HourBucket(base)..on = 59;
    expect(onFraction(b), isNull);
    b.off = 61;
    expect(onFraction(b), closeTo(59 / 120, 1e-9));
  });

  test('countOutages counts on→off transitions after a time', () {
    final t = base;
    final segs = [
      seg(t, t.add(const Duration(hours: 1)), GridState.on),
      seg(t.add(const Duration(hours: 1)), t.add(const Duration(hours: 2)), GridState.off),
      seg(t.add(const Duration(hours: 2)), t.add(const Duration(hours: 3)), GridState.on),
      seg(t.add(const Duration(hours: 3)), t.add(const Duration(hours: 4)), GridState.off),
    ];
    expect(countOutages(segs, t), 2);
    expect(countOutages(segs, t.add(const Duration(hours: 2))), 1);
  });

  test('last24Hours ends with the current hour', () {
    final now = DateTime(2026, 11, 20, 14, 25);
    final b = last24Hours(const [], now);
    expect(b.length, 24);
    expect(b.last.start, DateTime(2026, 11, 20, 14));
    expect(b.first.start, DateTime(2026, 11, 19, 15));
  });

  test('last7Days returns 7 local days ending today', () {
    final now = DateTime(2026, 11, 20, 14, 25);
    final d = last7Days(const [], now);
    expect(d.length, 7);
    expect(d.last.first.start, DateTime(2026, 11, 20));
    expect(d.first.first.start, DateTime(2026, 11, 14));
  });

  test('formatHours / formatDuration', () {
    expect(formatHours(0), '0h 00m');
    expect(formatHours(5.5), '5h 30m');
    expect(formatHours(1.9999), '2h 00m');
    expect(formatDuration(const Duration(minutes: 45)), '45m');
    expect(formatDuration(const Duration(minutes: 125)), '2h 5m');
    expect(formatDuration(const Duration(minutes: -5)), '0m');
  });

  test('parseUtc accepts timestamps with and without Z', () {
    final a = parseUtc('2026-11-20T08:00:00Z');
    final b = parseUtc('2026-11-20T08:00:00');
    expect(a, b);
    expect(a.toUtc().hour, 8);
  });
}
