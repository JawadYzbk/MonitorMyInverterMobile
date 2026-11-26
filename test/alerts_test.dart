import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/models.dart';
import 'package:wattwise/services/alerts.dart';

Telemetry reading(int minute, double acIn, {String status = 'Online'}) => Telemetry.fromJson({
      'timestamp': '2026-11-20T10:${minute.toString().padLeft(2, '0')}:00Z',
      'acInputVoltage': acIn,
      'status': status,
      'batteryCapacity': 80,
    });

void main() {
  group('GridWatcher', () {
    test('first reading sets state silently', () {
      final w = GridWatcher();
      expect(w.update(reading(0, 230)), isNull);
      expect(w.state, GridState.on);
    });

    test('a change needs two new readings in a row', () {
      final w = GridWatcher()..update(reading(0, 230));
      expect(w.update(reading(1, 0)), isNull);
      // Same reading polled again does not count.
      expect(w.update(reading(1, 0)), isNull);
      expect(w.update(reading(2, 0)), GridState.off);
      expect(w.state, GridState.off);
    });

    test('a single blip is ignored', () {
      final w = GridWatcher()..update(reading(0, 230));
      expect(w.update(reading(1, 0)), isNull);
      expect(w.update(reading(2, 230)), isNull);
      expect(w.update(reading(3, 0)), isNull);
      expect(w.state, GridState.on);
    });

    test('offline readings are skipped', () {
      final w = GridWatcher()..update(reading(0, 230));
      expect(w.update(reading(1, 0, status: 'Offline')), isNull);
      expect(w.update(reading(2, 0, status: 'Offline')), isNull);
      expect(w.state, GridState.on);
    });
  });

  group('LowBatteryGate', () {
    final t0 = DateTime(2026, 11, 20, 10);

    DateTime at(int s) => t0.add(Duration(seconds: s));

    test('alerts on the second low reading, then at most every 2 minutes', () {
      final g = LowBatteryGate();
      expect(g.shouldAlert(20, 25, at(0), readingKey: 1), isFalse);
      expect(g.shouldAlert(20, 25, at(60), readingKey: 2), isTrue);
      expect(g.shouldAlert(20, 25, at(120), readingKey: 3), isFalse);
      expect(g.shouldAlert(20, 25, at(181), readingKey: 4), isTrue);
    });

    test('the same reading polled twice does not confirm', () {
      final g = LowBatteryGate();
      expect(g.shouldAlert(20, 25, at(0), readingKey: 1), isFalse);
      expect(g.shouldAlert(20, 25, at(10), readingKey: 1), isFalse);
    });

    test('a one-off drop to 0 % never alerts', () {
      final g = LowBatteryGate();
      expect(g.shouldAlert(64, 25, at(0), readingKey: 1), isFalse);
      expect(g.shouldAlert(0, 25, at(60), readingKey: 2), isFalse);
      expect(g.shouldAlert(63, 25, at(120), readingKey: 3), isFalse);
    });

    test('empty readings at 0 V are ignored', () {
      final g = LowBatteryGate();
      expect(g.shouldAlert(0, 25, at(0), readingKey: 1, batteryVoltage: 0), isFalse);
      expect(g.shouldAlert(0, 25, at(60), readingKey: 2, batteryVoltage: 0), isFalse);
    });

    test('re-arms after recovering', () {
      final g = LowBatteryGate();
      g.shouldAlert(20, 25, at(0), readingKey: 1);
      expect(g.shouldAlert(20, 25, at(60), readingKey: 2), isTrue);
      expect(g.shouldAlert(30, 25, at(70), readingKey: 3), isFalse);
      expect(g.shouldAlert(24, 25, at(80), readingKey: 4), isFalse);
      expect(g.shouldAlert(24, 25, at(90), readingKey: 5), isTrue);
    });
  });
}
