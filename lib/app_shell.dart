import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/calendar/calendar_screen.dart';
import 'features/courses/courses_screen.dart';
import 'features/games/games_screen.dart';
import 'features/home/home_screen.dart';
import 'features/import_data/import_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/settings/settings_screen.dart';

/// Responsive app shell: bottom navigation on narrow screens (Android),
/// sidebar navigation on wide screens (desktop).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _Destination {
  final String label;
  final Widget screen;
  final IconData icon;
  final IconData selectedIcon;

  const _Destination(this.label, this.screen, this.icon, this.selectedIcon);
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _destinations = [
    _Destination('Home', HomeScreen(), Icons.home_outlined, Icons.home),
    _Destination(
      'Courses',
      CoursesScreen(),
      Icons.school_outlined,
      Icons.school,
    ),
    _Destination(
      'Games',
      GamesScreen(),
      Icons.sports_esports_outlined,
      Icons.sports_esports,
    ),
    _Destination(
      'Progress',
      ProgressScreen(),
      Icons.insights_outlined,
      Icons.insights,
    ),
    _Destination(
      'Calendar',
      CalendarScreen(),
      Icons.calendar_month_outlined,
      Icons.calendar_month,
    ),
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.widthOf(context) >= 800;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'E',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
              trailing: Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Import lessons',
                      onPressed: () => _openImport(context),
                      icon: const Icon(Icons.upload_file_outlined),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () => _openSettings(context),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: _destinations[_index].screen,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_destinations[_index].label)),
      body: _destinations[_index].screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }

  void _openImport(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ImportScreen()));
  }

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }
}
