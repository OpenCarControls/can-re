import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ui/can_trace_view.dart';
import 'ui/can_dashboard_view.dart';
import 'ui/app_shell.dart';
import 'ui/dbc_editor_screen.dart';
import 'providers/dbc_provider.dart';
import 'dart:ui';

void main() {
  runApp(
    const ProviderScope(
      child: OpenCarControlsApp(),
    ),
  );
}

final _navigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _navigatorKey,
  initialLocation: '/trace',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/trace',
              builder: (context, state) => const CanTraceView(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const CanDashboardView(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/dbc_editor',
      builder: (context, state) => const DbcEditorScreen(),
    ),
  ],
);

class OpenCarControlsApp extends ConsumerStatefulWidget {
  const OpenCarControlsApp({super.key});

  @override
  ConsumerState<OpenCarControlsApp> createState() => _OpenCarControlsAppState();
}

class _OpenCarControlsAppState extends ConsumerState<OpenCarControlsApp> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onExitRequested: _handleExitRequest,
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _handleExitRequest() async {
    final state = ref.read(dbcProvider);
    if (!state.hasUnsavedChanges) return AppExitResponse.exit;
    if (state.activeDbc != null && state.activeDbc!.messages.isEmpty && state.activeDbc!.unparsedLines.isEmpty) return AppExitResponse.exit;

    final context = _navigatorKey.currentContext;
    if (context == null) return AppExitResponse.exit;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have an unsaved draft of your DBC file. Are you sure you want to exit and discard it? (Note: It is auto-saved locally and will restore if you close forcefully)'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit Anyway'),
          ),
        ],
      ),
    );

    if (result == true) {
      return AppExitResponse.exit;
    }
    return AppExitResponse.cancel;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OpenCarControls CAN RE',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueGrey,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      routerConfig: _router,
    );
  }
}
