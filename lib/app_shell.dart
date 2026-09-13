import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'features/games/games_screen.dart';
import 'features/home/home_screen.dart';
import 'features/import_data/import_screen.dart';
import 'features/learn/learn_screen.dart';
import 'features/practice/practice_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/settings/settings_screen.dart';

/// E app shell (spec §7): five bottom tabs on phones (Home, Learn,
/// Practice, Games, Progress), a purpose-built sidebar on desktop —
/// not a stretched phone layout.
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
    _Destination('Learn', LearnScreen(), Icons.school_outlined, Icons.school),
    _Destination(
      'Practice',
      PracticeScreen(),
      Icons.refresh_outlined,
      Icons.refresh,
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
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.widthOf(context) >= 800;
    // Review badge on Practice (count shown in tooltip + Practice screen
    // itself — never color-only).
    final due = ref
        .watch(dueCountProvider)
        .maybeWhen(data: (c) => c, orElse: () => 0);
    if (wide) return _desktop(context, due);
    return _mobile(context, due);
  }

  // ----- Mobile: bottom navigation, one-handed use (spec §54). -----

  Widget _mobile(BuildContext context, int due) {
    return Scaffold(
      // Mockup Home has no top bar — the greeting leads directly.
      appBar: _index == 0
          ? null
          : AppBar(title: Text(_destinations[_index].label)),
      body: IndexedStack(
        index: _index,
        children: [for (final d in _destinations) d.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: [
          for (var i = 0; i < _destinations.length; i++)
            NavigationDestination(
              icon: _badge(
                _destinations[i].icon,
                show: i == 2 && due > 0,
                count: due,
              ),
              selectedIcon: _badge(
                _destinations[i].selectedIcon,
                show: i == 2 && due > 0,
                count: due,
              ),
              label: _destinations[i].label,
              tooltip: i == 2 && due > 0
                  ? 'Practice — $due due'
                  : _destinations[i].label,
            ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, {required bool show, required int count}) {
    if (!show) return Icon(icon);
    final label = count > 99 ? '99+' : '$count';
    return Badge(label: Text(label), child: Icon(icon));
  }

  // ----- Desktop: sidebar + centered content column (spec §53). -----

  Widget _desktop(BuildContext context, int due) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 248,
            color: scheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'E',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Text(
                    'Your language. Your pace.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                for (var i = 0; i < _destinations.length; i++)
                  _railTile(
                    context,
                    selected: i == _index,
                    icon: i == _index
                        ? _destinations[i].selectedIcon
                        : _destinations[i].icon,
                    label: _destinations[i].label,
                    trailing: i == 2 && due > 0 ? '$due due' : null,
                    onTap: () => _go(i),
                  ),
                const Spacer(),
                _railTile(
                  context,
                  selected: false,
                  icon: Icons.upload_file_outlined,
                  label: 'Import / Export',
                  onTap: () => _openImport(context),
                ),
                _railTile(
                  context,
                  selected: false,
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => _openSettings(context),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: scheme.outlineVariant),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: IndexedStack(
                  index: _index,
                  children: [for (final d in _destinations) d.screen],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _railTile(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.7)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                ),
                if (trailing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      trailing,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openImport(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ImportScreen()));
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }
}
