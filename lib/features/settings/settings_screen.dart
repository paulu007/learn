import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_info.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';

/// Settings: appearance, font size, learning, keyboard info, data
/// (backup/restore/export/import), and the danger zone.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AsyncView<UserSettings>(
        value: settings,
        builder: (s) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _appearanceCard(context, ref, s),
            _fontCard(context, ref, s),
            _learningCard(context, ref, s),
            _keyboardCard(context),
            _dataCard(context, ref),
            _dangerCard(context, ref),
            _aboutCard(context),
          ],
        ),
      ),
    );
  }

  Widget _appearanceCard(BuildContext context, WidgetRef ref, UserSettings s) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          RadioGroup<String>(
            groupValue: s.themeMode,
            onChanged: (v) => ref.read(settingsProvider.notifier).setTheme(v!),
            child: Column(
              children: [
                for (final mode in ['light', 'dark', 'system'])
                  RadioListTile<String>(
                    title: Text(mode[0].toUpperCase() + mode.substring(1)),
                    value: mode,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fontCard(BuildContext context, WidgetRef ref, UserSettings s) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Font Size',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          RadioGroup<String>(
            groupValue: s.fontSize,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setFontSize(AppFontSize.fromName(v)),
            child: Column(
              children: [
                for (final size in AppFontSize.values)
                  RadioListTile<String>(
                    title: Text(size.label),
                    value: size.name,
                  ),
              ],
            ),
          ),
          const Divider(),
          Text(
            'This is sample text.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _learningCard(BuildContext context, WidgetRef ref, UserSettings s) {
    final goalCtrl = TextEditingController(text: s.dailyGoal.toString());
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: goalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily goal (activities)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final goal = int.tryParse(goalCtrl.text.trim());
                  if (goal != null && goal > 0 && goal <= 500) {
                    await ref
                        .read(settingsProvider.notifier)
                        .setDailyGoal(goal);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Daily goal saved.')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Review: items you mark Again/Hard come back tomorrow; '
            'Good/Easy items return in several days. '
            'A day counts toward your streak when you reach the daily goal.',
          ),
        ],
      ),
    );
  }

  Widget _keyboardCard(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keyboard',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'E always uses its own in-app keyboard — the system keyboard never opens. '
            'Layouts: English (QWERTY), Persian (ض ص ث…), German (QWERTZ + Ä Ö Ü ß), '
            'plus a Latin layout for other languages.',
          ),
        ],
      ),
    );
  }

  Widget _dataCard(BuildContext context, WidgetRef ref) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _dataButton(
            context,
            'Backup Everything',
            Icons.backup_outlined,
            () async {
              final path = await ref.read(repositoryProvider).writeBackup();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Backup saved to $path')),
                );
              }
            },
          ),
          _dataButton(
            context,
            'Restore Backup…',
            Icons.restore_outlined,
            () => _restoreDialog(context, ref),
          ),
          _dataButton(
            context,
            'Export Progress (JSON)…',
            Icons.download_outlined,
            () async {
              final path = await ref.read(repositoryProvider).writeBackup();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Data exported to $path')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _dataButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }

  Future<void> _restoreDialog(BuildContext context, WidgetRef ref) async {
    final pathCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste the full path of an E backup (.json) file. '
              'This replaces all current data.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pathCtrl,
              decoration: const InputDecoration(labelText: 'Backup file path'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok == true && pathCtrl.text.trim().isNotEmpty) {
      try {
        final counts = await ref
            .read(repositoryProvider)
            .restoreBackup(pathCtrl.text.trim());
        ref.invalidate(coursesProvider);
        refreshAfterStudy(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Restored: ${counts.values.fold(0, (a, b) => a + b)} rows.',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Restore failed: $e')));
        }
      }
    }
  }

  Widget _dangerCard(BuildContext context, WidgetRef ref) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danger Zone',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppConstants.incorrectRed,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final ok = await confirmAction(
                  context,
                  title: 'Reset all progress?',
                  message: 'Remove ALL learning progress but keep your courses and lessons? This action cannot be undone.',
                  confirmLabel: 'Reset Progress',
                  danger: false,
                );
                if (ok) {
                  await ref.read(repositoryProvider).resetAllProgress();
                  refreshAfterStudy(ref);
                }
              },
              child: const Text('Reset All Progress'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.incorrectRed,
              ),
              onPressed: () async {
                final ok = await confirmAction(
                  context,
                  title: 'Clear all lessons?',
                  message: 'Delete ALL courses, lessons, items, and progress? This action cannot be undone.',
                  confirmLabel: 'Clear All Lessons',
                );
                if (ok) {
                  await ref.read(repositoryProvider).clearAllContent();
                  ref.invalidate(coursesProvider);
                  refreshAfterStudy(ref);
                }
              },
              child: const Text('Clear All Lessons'),
            ),
          ),
        ],
      ),
    );
  }

  /// App identity + semantic version (spec §69).
  Widget _aboutCard(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${AppInfo.name} ${AppInfo.version}',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(AppInfo.tagline, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
