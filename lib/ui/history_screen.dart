import 'package:flutter/material.dart';

import '../grid.dart' show clock;
import '../models.dart';
import '../state/app_state.dart';
import 'theme.dart';

/// Port of app/(dashboard)/archive/page.tsx: filtered, sorted, paged telemetry log.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _sortColumns = {
    'timestamp': 'Time',
    'model': 'Inverter model',
    'loadPower': 'Load (W)',
    'batteryCapacity': 'Battery (%)',
    'batteryVoltage': 'Battery volt (V)',
    'pvVoltage': 'PV input (V)',
  };
  static const _pageSizes = [10, 25, 50, 100, 200];

  final _q = HistoryQuery(limit: 25);
  final _minLoad = TextEditingController();
  final _maxLoad = TextEditingController();
  final _minBat = TextEditingController();
  final _maxBat = TextEditingController();
  final _model = TextEditingController();
  DateTime? _start;
  DateTime? _end;

  List<HistoryLog> _rows = [];
  int _total = 0;
  int _pages = 0;
  bool _loading = false;
  String? _error;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  @override
  void dispose() {
    for (final c in [_minLoad, _maxLoad, _minBat, _maxBat, _model]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await AppScope.read(context).loadHistory(_q);
      if (!mounted) return;
      setState(() {
        _rows = page.data;
        _total = page.total;
        _pages = page.pages;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    double? num(TextEditingController c) => double.tryParse(c.text.trim());
    _q
      ..page = 1
      ..startDate = _start != null ? _ymd(_start!) : null
      ..endDate = _end != null ? _ymd(_end!) : null
      ..minLoadPower = num(_minLoad)
      ..maxLoadPower = num(_maxLoad)
      ..minBatteryVoltage = num(_minBat)
      ..maxBatteryVoltage = num(_maxBat)
      ..model = _model.text.trim().isEmpty ? null : _model.text.trim();
    FocusScope.of(context).unfocus();
    _load();
  }

  void _resetFilters() {
    for (final c in [_minLoad, _maxLoad, _minBat, _maxBat, _model]) {
      c.clear();
    }
    _start = null;
    _end = null;
    _applyFilters();
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDate: (start ? _start : _end) ?? now,
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  void _goTo(int page) {
    if (page < 1 || page > _pages) return;
    _q.page = page;
    _load();
  }

  int get _activeFilters => [
        _q.startDate,
        _q.endDate,
        _q.minLoadPower,
        _q.maxLoadPower,
        _q.minBatteryVoltage,
        _q.maxBatteryVoltage,
        _q.model,
      ].where((v) => v != null).length;

  @override
  Widget build(BuildContext context) {
    final threshold = AppScope.of(context).threshold;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        children: [
          Row(children: [
            const Expanded(child: Text('History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: C.battery.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.battery.withValues(alpha: 0.25)),
              ),
              child: Text('$_total readings', style: const TextStyle(fontSize: 12, color: C.battery)),
            ),
          ]),
          const SizedBox(height: 12),
          _filterCard(),
          const SizedBox(height: 10),
          _sortBar(),
          const SizedBox(height: 10),
          if (_loading && _rows.isEmpty)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (_error != null && _rows.isEmpty)
            _empty(_error!)
          else if (_rows.isEmpty)
            _empty('No readings match these filters.')
          else ...[
            AnimatedOpacity(
              opacity: _loading ? 0.5 : 1,
              duration: const Duration(milliseconds: 200),
              child: Column(children: [for (final r in _rows) _RowCard(r, threshold)]),
            ),
            const SizedBox(height: 8),
            _pager(),
          ],
        ],
      ),
    );
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ]),
      );

  Widget _filterCard() {
    Widget numField(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label),
          ),
        );
    Widget dateButton(bool start) {
      final v = start ? _start : _end;
      return Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: C.border),
            foregroundColor: v == null ? C.muted : C.text,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => _pickDate(start),
          icon: const Icon(Icons.calendar_today, size: 15),
          label: Text(v == null ? (start ? 'Start date' : 'End date') : _ymd(v)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          leading: const Icon(Icons.filter_list, color: C.muted),
          title: Text(_activeFilters == 0 ? 'Filters' : 'Filters · $_activeFilters active',
              style: const TextStyle(fontSize: 14)),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            Row(children: [dateButton(true), const SizedBox(width: 8), dateButton(false)]),
            const SizedBox(height: 10),
            Row(children: [numField(_minLoad, 'Min load W'), const SizedBox(width: 8), numField(_maxLoad, 'Max load W')]),
            const SizedBox(height: 10),
            Row(children: [
              numField(_minBat, 'Min battery V'),
              const SizedBox(width: 8),
              numField(_maxBat, 'Max battery V'),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Inverter model', prefixIcon: Icon(Icons.search, size: 18)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _resetFilters, child: const Text('Reset'))),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(foregroundColor: C.bg),
                  onPressed: _applyFilters,
                  child: const Text('Filter'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sortBar() {
    return Row(children: [
      const Icon(Icons.sort, size: 18, color: C.muted),
      const SizedBox(width: 8),
      Expanded(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _q.sortBy,
            dropdownColor: C.panel,
            style: const TextStyle(fontSize: 13.5, color: C.text),
            items: [
              for (final e in _sortColumns.entries) DropdownMenuItem(value: e.key, child: Text('Sort by ${e.value}')),
            ],
            onChanged: (v) {
              if (v == null) return;
              _q
                ..sortBy = v
                ..order = 'desc'
                ..page = 1;
              _load();
            },
          ),
        ),
      ),
      IconButton(
        tooltip: _q.order == 'desc' ? 'Descending' : 'Ascending',
        onPressed: () {
          _q
            ..order = _q.order == 'desc' ? 'asc' : 'desc'
            ..page = 1;
          _load();
        },
        icon: Icon(_q.order == 'desc' ? Icons.arrow_downward : Icons.arrow_upward, size: 18, color: C.battery),
      ),
    ]);
  }

  Widget _pager() {
    final from = _total == 0 ? 0 : (_q.page - 1) * _q.limit + 1;
    final to = (_q.page * _q.limit).clamp(0, _total);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          onPressed: _q.page > 1 ? () => _goTo(_q.page - 1) : null,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous page',
        ),
        Text('Page ${_q.page} of ${_pages == 0 ? 1 : _pages}', style: const TextStyle(fontSize: 13)),
        IconButton(
          onPressed: _q.page < _pages ? () => _goTo(_q.page + 1) : null,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next page',
        ),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Showing $from–$to of $_total · ', style: const TextStyle(fontSize: 12, color: C.muted)),
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _q.limit,
            dropdownColor: C.panel,
            style: const TextStyle(fontSize: 12, color: C.text),
            items: [for (final n in _pageSizes) DropdownMenuItem(value: n, child: Text('$n per page'))],
            onChanged: (v) {
              if (v == null) return;
              _q
                ..limit = v
                ..page = 1;
              _load();
            },
          ),
        ),
      ]),
    ]);
  }
}

class _RowCard extends StatelessWidget {
  final HistoryLog r;
  final int threshold;

  const _RowCard(this.r, this.threshold);

  static String _date(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${clock(t)}';

  @override
  Widget build(BuildContext context) {
    final low = r.batteryCapacity < threshold;
    final batColor = low ? C.danger : C.battery;
    const label = TextStyle(fontSize: 11, color: C.faint);
    const value = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, fontFeatures: tabular);
    Widget cell(String l, String v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: label),
            const SizedBox(height: 2),
            Text(v, style: value),
          ]),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(_date(r.timestamp),
                style: const TextStyle(fontSize: 12.5, color: C.muted, fontFeatures: tabular)),
          ),
          Text(r.model.isEmpty ? 'Off Grid' : r.model.toUpperCase(),
              style: const TextStyle(fontSize: 11, color: C.faint, letterSpacing: 0.4)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          cell('Load', '${r.loadPower.round()} W'),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Battery', style: label),
              const SizedBox(height: 2),
              Text('${r.batteryCapacity.round()}%', style: value.copyWith(color: low ? C.danger : null)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (r.batteryCapacity / 100).clamp(0, 1),
                  minHeight: 3,
                  color: batColor,
                  backgroundColor: C.border,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          cell('Battery V', '${r.batteryVoltage.toStringAsFixed(1)} V'),
          cell('PV input', '${r.pvVoltage.toStringAsFixed(1)} V'),
        ]),
      ]),
    );
  }
}
