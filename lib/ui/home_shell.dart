import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'history_screen.dart';
import 'overview_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keeps "updated x min ago" fresh.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String? _updatedAgo(DateTime? t) {
    if (t == null) return null;
    final min = DateTime.now().difference(t).inSeconds / 60;
    final m = min.round().clamp(0, 1 << 30);
    if (m < 1) return 'just now';
    if (m < 60) return '$m min ago';
    return '${(m / 60).round()} h ago';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final online = s.telemetry?.online ?? false;
    final ago = _updatedAgo(s.lastUpdate ?? (s.history.isNotEmpty ? s.history.first.timestamp : null));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: C.battery.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.bolt, size: 18, color: C.battery),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Pi Q6 Monitor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Row(children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: online ? C.battery : const Color(0xFF52525B), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '${online ? 'Live' : 'Offline'}${ago != null ? ' · $ago' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: C.muted),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: 'Refresh now',
            onPressed: s.refreshing ? null : () => s.refreshAll(),
            icon: s.refreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [OverviewScreen(), HistoryScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}
