import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:home_widget/home_widget.dart';

import 'services/monitor_service.dart';
import 'services/settings.dart';
import 'services/widget_sync.dart';
import 'state/app_state.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MonitorService.init();
  // Refresh button on the home screen widgets (Android only).
  if (WidgetSync.supported) {
    unawaited(HomeWidget.registerInteractivityCallback(widgetBackgroundCallback));
  }
  final settings = await Settings.load();
  final state = AppState(settings);
  runApp(WattWiseApp(state: state));
  await state.bootstrap();
}

class WattWiseApp extends StatelessWidget {
  final AppState state;
  const WattWiseApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'WattWise',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Keeps the background service alive when the user swipes back out of the app.
        home: const WithForegroundTask(child: _Root()),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return switch (s.auth) {
      AuthStatus.starting => const Scaffold(body: Center(child: CircularProgressIndicator())),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.signedIn => const HomeShell(),
    };
  }
}
