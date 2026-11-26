import 'package:flutter_test/flutter_test.dart';
import 'package:piq6_monitor/models.dart';
import 'package:piq6_monitor/services/alerts.dart';

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

    test('alerts at most every 2 minutes while low', () {
      final g = LowBatteryGate();
      expect(g.shouldAlert(20, 25, t0), isTrue);
      expect(g.shouldAlert(20, 25, t0.add(const Duration(seconds: 60))), isFalse);
      expect(g.shouldAlert(20, 25, t0.add(const Duration(seconds: 121))), isTrue);
    });

    test('re-arms after recovering', () {
      final g = LowBatteryGate();
      expect(g.shouldAlert(20, 25, t0), isTrue);
      expect(g.shouldAlert(30, 25, t0.add(const Duration(seconds: 10))), isFalse);
      expect(g.shouldAlert(24, 25, t0.add(const Duration(seconds: 20))), isTrue);
    });
  });
}
