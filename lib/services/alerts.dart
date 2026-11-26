// Alert rules, ported from ShinePlatform/tray_app.py so phone and PC behave the same.
import '../grid.dart';
import '../models.dart';

/// Follows grid on/off from live readings. A change is reported only after
/// [confirmPolls] *new* readings in a row agree (the server stores roughly one
/// reading a minute while clients poll more often).
class GridWatcher {
  static const confirmPolls = 2;

  GridState? state;
  Object? _lastKey;
  GridState? _candidate;
  int _count = 0;

  /// Returns the new state when a change is confirmed, otherwise null.
  GridState? update(Telemetry t, {double threshold = defaultGridOnVoltage}) {
    if (!t.online) return null; // stale reading; don't guess
    final Object key = t.timestamp ??
        Object.hash(t.acInputVoltage, t.loadPower, t.batteryVoltage, t.pvInputPower);
    if (key == _lastKey) return null;
    _lastKey = key;
    final observed = t.acInputVoltage >= threshold ? GridState.on : GridState.off;
    if (state == null) {
      state = observed; // first reading: set silently
      return null;
    }
    if (observed == state) {
      _candidate = null;
      _count = 0;
      return null;
    }
    if (observed == _candidate) {
      _count += 1;
    } else {
      _candidate = observed;
      _count = 1;
    }
    if (_count >= confirmPolls) {
      state = observed;
      _candidate = null;
      _count = 0;
      return observed;
    }
    return null;
  }
}

/// Low battery alarm: at most once every [interval] while the battery stays
/// below the threshold; re-arms as soon as it recovers.
///
/// The cloud now and then sends an empty reading (0 V, 0 %) for a minute. So a
/// reading at 0 V never counts, and the battery must read low on
/// [confirmReadings] *new* readings in a row before the first alarm.
class LowBatteryGate {
  static const interval = Duration(seconds: 120);
  static const confirmReadings = 2;
  DateTime? _last;
  Object? _lastKey;
  int _lowCount = 0;

  /// [readingKey] tells new readings apart from the same one polled again
  /// (null counts every call as new). [batteryVoltage] <= 0 marks an empty reading.
  bool shouldAlert(int battery, int threshold, DateTime now,
      {Object? readingKey, double? batteryVoltage}) {
    if (batteryVoltage != null && batteryVoltage <= 0) return false;
    if (battery >= threshold) {
      _last = null;
      _lastKey = null;
      _lowCount = 0;
      return false;
    }
    if (readingKey == null || readingKey != _lastKey) {
      _lastKey = readingKey;
      _lowCount += 1;
    }
    if (_lowCount < confirmReadings) return false;
    if (_last != null && now.difference(_last!) <= interval) return false;
    _last = now;
    return true;
  }
}
