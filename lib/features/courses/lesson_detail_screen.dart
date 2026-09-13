import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';
import '../learning/lesson_session_screen.dart';

/// Lesson overview: counts, progress, item list, and Start/Continue.
class LessonDetailScreen extends ConsumerWidget {
  final String lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(lessonOfProvider(lessonId));
    final items = ref.watch(lessonItemsProvider(lessonId));
    final counts = ref.watch(typeCountsProvider(lessonId));
    final status = ref.watch(statusCountsProvider(lessonId));
    final AsyncValue<Map<String, ItemProgress>> progressMap = items.when(
      data: (list) =>
          ref.watch(_progressMapProvider(list.map((e) => e.id).toList())),
      loading: () => const AsyncValue<Map<String, ItemProgress>>.loading(),
      error: (e, s) => AsyncValue<Map<String, ItemProgress>>.error(e, s),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lesson.maybeWhen(
            data: (l) => l?.title ?? 'Lesson',
            orElse: () => 'Lesson',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          counts.when(
            loading: () => const SectionCard(child: LinearProgressIndicator()),
            error: (_, _) => const SizedBox.shrink(),
            data: (c) {
              final words = c['vocab'] ?? 0;
              final sentences =
                  (c['sentence'] ?? 0) + (c['communication'] ?? 0);
              return SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Words: $words · Sentences: $sentences',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    status.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (s) {
                        final total = s.values.fold<int>(0, (a, b) => a + b);
                        final mastered = s['mastered'] ?? 0;
                        return LabeledProgress(
                          value: total == 0 ? 0 : mastered / total,
                          label: 'Mastered $mastered / $total',
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Start Learning',
                      icon: Icons.play_arrow,
                      onPressed: () async {
                        await ref
                            .read(repositoryProvider)
                            .setCurrentLesson(
                              lesson.value?.courseId ?? '',
                              lessonId,
                            );
                        final settings = await ref.read(
                          settingsProvider.future,
                        );
                        await ref
                            .read(settingsProvider.notifier)
                            .setLastLesson(
                              settings.lastCourseId ?? lesson.value?.courseId,
                              lessonId,
                            );
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  LessonSessionScreen(lessonId: lessonId),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          AsyncView<List<LearningItem>>(
            value: items,
            builder: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.list_alt_outlined,
                  title: 'No items in this lesson',
                  message: 'Import a CSV or Excel file to add vocabulary and sentences.',
                );
              }
              return Column(
                children: [
                  for (final item in list)
                    _itemTile(context, item, progressMap),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _itemTile(
    BuildContext context,
    LearningItem item,
    AsyncValue<Map<String, ItemProgress>> progressMap,
  ) {
    final status = progressMap.maybeWhen(
      data: (m) => m[item.id]?.status ?? 'new',
      orElse: () => 'new',
    );
    return Card(
      child: ListTile(
        title: Text(item.sourceText),
        subtitle: Text(
          '${item.targetText}${item.hint.isNotEmpty ? '\nHint: ${item.hint}' : ''}',
        ),
        isThreeLine: item.hint.isNotEmpty,
        trailing: _statusChip(status),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'mastered' => Colors.green,
      'review' => Colors.blue,
      'learning' => Colors.orange,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

final _progressMapProvider =
    FutureProvider.family<Map<String, ItemProgress>, List<String>>((
      ref,
      ids,
    ) async {
      return ref.watch(repositoryProvider).progressForItems(ids);
    });
