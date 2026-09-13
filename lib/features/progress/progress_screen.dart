import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/design/e_design.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';
import '../calendar_stats/calendar_stats_screen.dart';

/// Progress tab (spec §32): streak hero, learning-progress bars, stats,
/// weak words — with links into Calendar & Statistics (kept separate so
/// Progress stays glanceable, spec §4).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(totalsProvider);
    final streak = ref.watch(streakProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshAfterStudy(ref),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          EAsyncView<StreakInfo>(
            value: streak,
            builder: (s) => _streakHero(context, s),
          ),
          EAsyncView<Map<String, int>>(
            value: totals,
            builder: (t) => _overviewCard(context, ref, t),
          ),
          _calendarStatsLinks(context),
          _weakWordsCard(context, ref),
        ],
      ),
    );
  }

  Widget _streakHero(BuildContext context, StreakInfo s) {
    return EDarkCard(
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(width: ESpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.current} day streak',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Longest: ${s.longest} days',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, int> t,
  ) {
    final items = t['items'] ?? 0;
    final mastered = t['mastered'] ?? 0;
    final vocab = t['vocab'] ?? 0;
    final sentences = t['sentences'] ?? 0;
    final correct = t['correct'] ?? 0;
    final wrong = t['wrong'] ?? 0;
    final attempts = correct + wrong;
    final accuracy = attempts == 0 ? 0 : ((correct / attempts) * 100).round();
    return ESectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ESectionTitle(title: 'Learning Progress'),
          const SizedBox(height: ESpacing.sm),
          FutureBuilder(
            future: ref.read(repositoryProvider).overallStatusCounts(),
            builder: (ctx, snap) {
              final s = snap.data ?? {};
              double frac(String key, int base) {
                if (base == 0) return 0;
                return (s[key] ?? 0) / base;
              }

              return Column(
                children: [
                  ELabeledProgress(
                    value: items == 0 ? 0 : mastered / items,
                    label: 'Overall mastered',
                  ),
                  const SizedBox(height: 8),
                  ELabeledProgress(
                    value: frac('mastered', vocab == 0 ? 1 : vocab),
                    label: 'Vocabulary ($vocab)',
                  ),
                  const SizedBox(height: 8),
                  ELabeledProgress(
                    value: frac('mastered', sentences == 0 ? 1 : sentences),
                    label: 'Sentences ($sentences)',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: ESpacing.md),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _stat(context, 'Total words', '$vocab'),
              _stat(context, 'Total sentences', '$sentences'),
              _stat(context, 'Mastered', '$mastered items'),
              _stat(context, 'Correct answers', '$correct'),
              _stat(context, 'Incorrect answers', '$wrong'),
              _stat(context, 'Accuracy', '$accuracy%'),
            ],
          ),
          FutureBuilder(
            future: ref.read(repositoryProvider).totalStudySeconds(),
            builder: (ctx, snap) {
              final secs = snap.data ?? 0;
              final mins = (secs / 60).round();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Study time: $mins min total'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _calendarStatsLinks(BuildContext context) {
    return Column(
      children: [
        ETile(
          icon: Icons.calendar_month_outlined,
          title: 'Calendar',
          subtitle: 'Studied days, streaks, activity',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CalendarStatsScreen(initialTab: 0),
            ),
          ),
        ),
        ETile(
          icon: Icons.bar_chart_outlined,
          title: 'Statistics',
          subtitle: 'Accuracy, study time, records',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CalendarStatsScreen(initialTab: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _weakWordsCard(BuildContext context, WidgetRef ref) {
    return ESectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ESectionTitle(title: 'Weak Words (review these)'),
          const SizedBox(height: ESpacing.sm),
          FutureBuilder(
            future: ref.read(repositoryProvider).weakItems(limit: 10),
            builder: (ctx, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Text('No weak words yet — keep learning!');
              }
              return Column(
                children: [
                  for (final (item, p) in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(item.sourceText),
                      subtitle: Text(item.targetText),
                      trailing: Text(
                        '${p.wrongCount} wrong / ${p.correctCount} right',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Days-since helper reused by calendar intensity.
int daysSinceLocal(DateTime from) => daysSince(from);
