// Data shapes returned by the MonitorMyInverter backend (see MonitorMyInverter/main.py).

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
double? _dn(dynamic v) => v == null ? null : _d(v);
int? _in(dynamic v) => v == null ? null : _d(v).round();

/// Parses a backend timestamp. Some rows come without a trailing `Z`; they are UTC.
DateTime parseUtc(String s) {
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(s);
  return DateTime.parse(hasZone ? s : '${s}Z').toLocal();
}

DateTime? parseUtcOrNull(dynamic s) {
  if (s is! String || s.isEmpty) return null;
  try {
    return parseUtc(s);
  } catch (_) {
    return null;
  }
}

class Telemetry {
  final DateTime? timestamp;
  final double loadPower;
  final double batteryVoltage;
  final double batteryCapacity;
  final double pvVoltage;
  final String model;
  final String status;
  final double acInputVoltage;
  final double acOutputVoltage;
  final double acOutputFrequency;
  final double loadPercent;
  final double pvInputPower;
  final double batteryChargingCurrent;
  final double batteryDischargingCurrent;

  Telemetry.fromJson(Map<String, dynamic> j)
      : timestamp = parseUtcOrNull(j['timestamp']),
        loadPower = _d(j['loadPower']),
        batteryVoltage = _d(j['batteryVoltage']),
        batteryCapacity = _d(j['batteryCapacity']),
        pvVoltage = _d(j['pvVoltage']),
        model = (j['model'] ?? '').toString(),
        status = (j['status'] ?? 'Offline').toString(),
        acInputVoltage = _d(j['acInputVoltage']),
        acOutputVoltage = _d(j['acOutputVoltage']),
        acOutputFrequency = _d(j['acOutputFrequency']),
        loadPercent = _d(j['loadPercent']),
        pvInputPower = _d(j['pvInputPower']),
        batteryChargingCurrent = _d(j['batteryChargingCurrent']),
        batteryDischargingCurrent = _d(j['batteryDischargingCurrent']);

  bool get online => status == 'Online';
  int get battery => batteryCapacity.round();
}

class HistoryLog {
  final int id;
  final DateTime timestamp;
  final String model;
  final double loadPower;
  final double batteryCapacity;
  final double batteryVoltage;
  final double pvVoltage;
  final double pvInputPower;

  HistoryLog.fromJson(Map<String, dynamic> j)
      : id = _in(j['id']) ?? 0,
        timestamp = parseUtcOrNull(j['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        model = (j['model'] ?? '').toString(),
        loadPower = _d(j['loadPower']),
        batteryCapacity = _d(j['batteryCapacity']),
        batteryVoltage = _d(j['batteryVoltage']),
        pvVoltage = _d(j['pvVoltage']),
        pvInputPower = _d(j['pvInputPower']);
}

class HistoryPage {
  final int total;
  final int page;
  final int limit;
  final int pages;
  final List<HistoryLog> data;

  HistoryPage({required this.total, required this.page, required this.limit, required this.pages, required this.data});

  factory HistoryPage.fromJson(dynamic j) {
    if (j is List) {
      final rows = j.map((e) => HistoryLog.fromJson(Map<String, dynamic>.from(e))).toList();
      return HistoryPage(total: rows.length, page: 1, limit: rows.length, pages: 1, data: rows);
    }
    final m = Map<String, dynamic>.from(j as Map);
    final rows = (m['data'] as List? ?? []).map((e) => HistoryLog.fromJson(Map<String, dynamic>.from(e))).toList();
    return HistoryPage(
      total: _in(m['total']) ?? rows.length,
      page: _in(m['page']) ?? 1,
      limit: _in(m['limit']) ?? rows.length,
      pages: _in(m['pages']) ?? 1,
      data: rows,
    );
  }
}

class HistoryQuery {
  int page;
  int limit;
  String sortBy;
  String order;
  String? startDate;
  String? endDate;
  double? minLoadPower;
  double? maxLoadPower;
  double? minBatteryVoltage;
  double? maxBatteryVoltage;
  String? model;

  HistoryQuery({
    this.page = 1,
    this.limit = 25,
    this.sortBy = 'timestamp',
    this.order = 'desc',
    this.startDate,
    this.endDate,
    this.minLoadPower,
    this.maxLoadPower,
    this.minBatteryVoltage,
    this.maxBatteryVoltage,
    this.model,
  });

  Map<String, String> toParams() {
    final p = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'sort_by': sortBy,
      'order': order,
    };
    void put(String k, Object? v) {
      if (v == null) return;
      final s = v.toString();
      if (s.isNotEmpty) p[k] = s;
    }

    put('start_date', startDate);
    put('end_date', endDate);
    put('min_load_power', minLoadPower);
    put('max_load_power', maxLoadPower);
    put('min_battery_voltage', minBatteryVoltage);
    put('max_battery_voltage', maxBatteryVoltage);
    put('model', model);
    return p;
  }
}

class Device {
  final String serialNumber;
  final String alias;
  final bool isSelected;

  Device.fromJson(Map<String, dynamic> j)
      : serialNumber = (j['serial_number'] ?? '').toString(),
        alias = (j['alias'] ?? j['serial_number'] ?? '').toString(),
        isSelected = j['is_selected'] == true;
}

enum GridState { on, off, unknown }

GridState gridStateFrom(dynamic v) => switch (v) {
      'on' => GridState.on,
      'off' => GridState.off,
      _ => GridState.unknown,
    };

class GridSegment {
  final DateTime start;
  final DateTime end;
  final GridState state;

  GridSegment(this.start, this.end, this.state);

  GridSegment.fromJson(Map<String, dynamic> j)
      : start = parseUtc(j['start'] as String),
        end = parseUtc(j['end'] as String),
        state = gridStateFrom(j['state']);
}

class GridResponse {
  final double threshold;
  final GridState current;
  final double? currentVoltage;
  final DateTime? lastSample;
  final DateTime? lastChange;
  final List<GridSegment> segments;

  GridResponse.fromJson(Map<String, dynamic> j)
      : threshold = _d(j['threshold'] ?? 100),
        current = gridStateFrom(j['current']),
        currentVoltage = _dn(j['currentVoltage']),
        lastSample = parseUtcOrNull(j['lastSample']),
        lastChange = parseUtcOrNull(j['lastChange']),
        segments = (j['segments'] as List? ?? [])
            .map((e) => GridSegment.fromJson(Map<String, dynamic>.from(e)))
            .toList();
}

class TimeWindow {
  final DateTime at;
  final DateTime earliest;
  final DateTime latest;

  TimeWindow(this.at, this.earliest, this.latest);

  static TimeWindow? fromJson(dynamic j) {
    if (j is! Map) return null;
    final at = parseUtcOrNull(j['at']);
    if (at == null) return null;
    return TimeWindow(at, parseUtcOrNull(j['earliest']) ?? at, parseUtcOrNull(j['latest']) ?? at);
  }
}

class Prediction extends TimeWindow {
  final GridState state;
  final bool overdue;

  Prediction(super.at, super.earliest, super.latest, this.state, this.overdue);

  static Prediction? fromJsonP(dynamic j) {
    final w = TimeWindow.fromJson(j);
    if (w == null) return null;
    return Prediction(w.at, w.earliest, w.latest, gridStateFrom(j['state']), j['overdue'] == true);
  }
}

class UpcomingBlock {
  final GridState state;
  final DateTime start;
  final DateTime end;

  UpcomingBlock(this.state, this.start, this.end);
}

class ForecastStats {
  final double? hoursPerDayThisWeek;
  final double? hoursPerDayLastWeek;
  final double? medianOutageMinutes;
  final double? medianOnMinutes;
  final double? cutsPerDay;

  ForecastStats.fromJson(Map<String, dynamic> j)
      : hoursPerDayThisWeek = _dn(j['hoursPerDayThisWeek']),
        hoursPerDayLastWeek = _dn(j['hoursPerDayLastWeek']),
        medianOutageMinutes = _dn(j['medianOutageMinutes']),
        medianOnMinutes = _dn(j['medianOnMinutes']),
        cutsPerDay = _dn(j['cutsPerDay']);
}

class GridForecast {
  final String status; // ready | learning
  final double coverageHours;
  final double neededHours;
  final GridState? currentState;
  final String patternKind;
  final String patternLabel;
  final double? patternMatch;
  final String method; // pattern | duration
  final Prediction? prediction;
  final TimeWindow? thenOn;
  final List<UpcomingBlock> upcoming;
  final String confidence; // high | medium | low | early
  final double? accuracyMedianErrorMinutes;
  final int accuracyTested;
  final List<double?> profile;
  final ForecastStats stats;

  GridForecast.fromJson(Map<String, dynamic> j)
      : status = (j['status'] ?? 'learning').toString(),
        coverageHours = _d(j['coverageHours']),
        neededHours = _d(j['neededHours'] ?? 1),
        currentState = j['current'] is Map ? gridStateFrom(j['current']['state']) : null,
        patternKind = (j['pattern']?['kind'] ?? 'none').toString(),
        patternLabel = (j['pattern']?['label'] ?? '').toString(),
        patternMatch = _dn(j['pattern']?['match']),
        method = (j['method'] ?? 'duration').toString(),
        prediction = Prediction.fromJsonP(j['prediction']),
        thenOn = TimeWindow.fromJson(j['thenOn']),
        upcoming = (j['upcoming'] as List? ?? [])
            .whereType<Map>()
            .map((b) => UpcomingBlock(gridStateFrom(b['state']), parseUtc(b['start']), parseUtc(b['end'])))
            .toList(),
        confidence = (j['confidence'] ?? 'early').toString(),
        accuracyMedianErrorMinutes = _dn(j['accuracy']?['medianErrorMinutes']),
        accuracyTested = _in(j['accuracy']?['tested']) ?? 0,
        profile = (j['profile'] as List? ?? []).map((e) => _dn(e)).toList(),
        stats = ForecastStats.fromJson(Map<String, dynamic>.from(j['stats'] as Map? ?? {}));
}
