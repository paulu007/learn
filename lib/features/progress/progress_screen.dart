import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';

/// Progress: per-type bars, totals, streaks, accuracy, weak words.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(totalsProvider);
    final streak = ref.watch(streakProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(totalsProvider);
        ref.invalidate(streakProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          AsyncView<Map<String, int>>(
            value: totals,
            builder: (t) => _overviewCard(context, ref, t),
          ),
          AsyncView<StreakInfo>(
            value: streak,
            builder: (s) => _streakCard(context, s),
          ),
          _weakWordsCard(context, ref),
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
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning Progress',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
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
                  LabeledProgress(
                    value: items == 0 ? 0 : mastered / items,
                    label: 'Overall mastered',
                  ),
                  const SizedBox(height: 8),
                  LabeledProgress(
                    value: frac('mastered', vocab == 0 ? 1 : vocab),
                    label: 'Vocabulary ($vocab)',
                  ),
                  const SizedBox(height: 8),
                  LabeledProgress(
                    value: frac('mastered', sentences == 0 ? 1 : sentences),
                    label: 'Sentences ($sentences)',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _stat('Total words', '$vocab'),
              _stat('Total sentences', '$sentences'),
              _stat('Completed lessons', '$mastered mastered items'),
              _stat('Correct answers', '$correct'),
              _stat('Incorrect answers', '$wrong'),
              _stat('Accuracy', '$accuracy%'),
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

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _streakCard(BuildContext context, StreakInfo s) {
    return SectionCard(
      child: Row(
        children: [
          const Icon(Icons.local_fire_department,
              color: Colors.orange, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current streak: ${s.current} days',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('Longest streak: ${s.longest} days'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weakWordsCard(BuildContext context, WidgetRef ref) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weak Words (review these)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder(
            future: ref.read(repositoryProvider).weakItems(limit: 10),
            builder: (ctx, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Text(
                  'No weak words yet — keep learning!',
                );
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
