import 'package:flutter/material.dart';

import '../grid.dart' show clock;
import '../services/monitor_service.dart';
import '../services/settings.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Web "Settings" (terminal) page + the tray app's settings dialog.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double? _threshold;
  final _server = TextEditingController();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    _server.text = AppScope.read(context).settings.apiUrl;
  }

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final saved = s.threshold;
    final value = _threshold ?? saved.toDouble();
    final dirty = value.round() != saved;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      children: [
        Panel(
          title: 'Low battery alert',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
              'You get an alarm when the battery drops below this level, repeated every 2 minutes while it stays low.',
              style: TextStyle(fontSize: 12.5, color: C.muted),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Slider(
                  value: value.clamp(0, 100),
                  max: 100,
                  divisions: 100,
                  label: '${value.round()}%',
                  activeColor: C.battery,
                  onChanged: (v) => setState(() => _threshold = v),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text('${value.round()}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.battery)),
              ),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: dirty ? () => setState(() => _threshold = null) : null,
                child: const Text('Revert'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(foregroundColor: C.bg),
                onPressed: dirty
                    ? () async {
                        await s.setThreshold(value.round());
                        setState(() => _threshold = null);
                        _snack('Alert level saved: ${value.round()}%');
                      }
                    : null,
                child: const Text('Save'),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Alerts & background',
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Column(children: [
            _switch('Low battery alarm', 'Siren notification when below the alert level', s.settings.alarmEnabled,
                s.setAlarm),
            _switch('Spoken warning', 'Reads the battery level out loud with the alarm', s.settings.voiceEnabled,
                s.setVoice),
            _switch('Grid sounds', 'Chime when grid power comes back, tones when it goes off',
                s.settings.gridSoundsEnabled, s.setGridSounds),
            if (MonitorService.supported)
              _switch(
                'Monitor in background',
                'Keeps watching while the app is closed and shows live status in the notification bar',
                s.settings.backgroundMonitoring,
                s.setBackgroundMonitoring,
              )
            else
              const ListTile(
                leading: Icon(Icons.info_outline, color: C.muted),
                title: Text('Alerts work while the app is open', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  "iPhone doesn't let apps keep checking in the background, so keep Pi Q6 Monitor open "
                  'when you want grid and battery alerts.',
                  style: TextStyle(fontSize: 12, color: C.faint),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    s.testAlarm();
                    _snack('Playing a test alarm…');
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Test alarm'),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Inverters',
          child: s.devices.isEmpty
              ? const Placeholder2('No inverters found yet.')
              : RadioGroup<String>(
                  groupValue: s.devices.where((d) => d.isSelected).map((d) => d.serialNumber).firstOrNull,
                  onChanged: (v) {
                    if (v != null) s.selectDevice(v);
                  },
                  child: Column(children: [
                    for (final d in s.devices)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: d.serialNumber,
                        title: Text(d.alias.isEmpty ? d.serialNumber : d.alias),
                        subtitle: Text(d.serialNumber, style: const TextStyle(fontSize: 12, color: C.faint)),
                        secondary: Icon(Icons.memory, color: d.isSelected ? C.battery : C.faint),
                      ),
                  ]),
                ),
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Recent readings',
          child: s.history.isEmpty
              ? const Placeholder2('Waiting for the first readings…')
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _intensityMatrix(s),
                  const SizedBox(height: 14),
                  for (final r in s.history.take(15))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text.rich(
                        TextSpan(style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), children: [
                          TextSpan(text: '[${clock(r.timestamp)}] ', style: const TextStyle(color: C.faint)),
                          TextSpan(text: 'load ${r.loadPower.round()} W  '),
                          TextSpan(
                            text: 'bat ${r.batteryCapacity.round()}%  ',
                            style: TextStyle(color: r.batteryCapacity < s.threshold ? C.danger : C.text),
                          ),
                          TextSpan(text: 'pv ${r.pvInputPower.round()} W', style: const TextStyle(color: C.solar)),
                        ]),
                      ),
                    ),
                ]),
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Server',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Gateway address', prefixIcon: Icon(Icons.dns)),
            ),
            const SizedBox(height: 6),
            const Text('Changing the server signs you out.', style: TextStyle(fontSize: 12, color: C.faint)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final changed = Settings.normalizeUrl(_server.text) != s.settings.apiUrl;
                  await s.setApiUrl(_server.text);
                  if (!changed && mounted) _snack('Server unchanged.');
                },
                child: const Text('Save server'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Account',
          child: Row(children: [
            const Icon(Icons.person_outline, color: C.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(s.settings.username.isEmpty ? 'Signed in' : s.settings.username)),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: C.danger, side: const BorderSide(color: C.border)),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('Background monitoring and alerts stop until you sign in again.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
                    ],
                  ),
                );
                if (ok == true) await s.logout();
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _switch(String title, String subtitle, bool value, Future<void> Function(bool) onChanged) => SwitchListTile(
        value: value,
        onChanged: (v) => onChanged(v),
        activeThumbColor: C.battery,
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: C.faint)),
      );

  /// Last 50 readings as cells, brighter = higher load (the web "intensity matrix").
  Widget _intensityMatrix(AppState s) {
    final rows = s.history.take(50).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionLabel('Load intensity · last 50 readings'),
      GridView.count(
        crossAxisCount: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: [
          for (var i = 0; i < 50; i++)
            if (i < rows.length)
              Tooltip(
                message: '${clock(rows[i].timestamp)} · ${rows[i].loadPower.round()} W · ${rows[i].batteryCapacity.round()}%',
                child: Container(
                  decoration: BoxDecoration(
                    color: C.load.withValues(alpha: 0.2 + 0.8 * (rows[i].loadPower / 3000).clamp(0, 1)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              )
            else
              Container(decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(3))),
        ],
      ),
    ]);
  }
}
