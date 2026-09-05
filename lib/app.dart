import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/admin/admin_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/home/home_screen.dart';
import 'state/providers.dart';

class Ec8aScannerApp extends ConsumerWidget {
  const Ec8aScannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return MaterialApp(
      title: 'EC8A Scanner',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: session.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : session.value == null
              ? const LoginScreen()
              : const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final isAdmin = (profile?['role'] ?? 'agent') == 'admin';
    final tabs = <Widget>[
      const HomeScreen(),
      const DashboardScreen(),
      if (isAdmin) const AdminScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.how_to_vote_outlined),
            label: 'My Units',
          ),
          const NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            label: 'Tally',
          ),
          if (isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              label: 'Admin',
            ),
        ],
      ),
    );
  }
}
