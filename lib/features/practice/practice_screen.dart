import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';
import '../courses/lesson_detail_screen.dart';
import '../import_data/import_screen.dart';
import '../learn/learn_screen.dart';

/// Practice tab (spec §7): a review-first queue grouped by lesson.
/// Due items come from the spaced-review schedule (spec §34, §35).
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueTotal = ref.watch(dueCountProvider);
    final dueByLesson = ref.watch(dueCountsByLessonProvider);
    final courses = ref.watch(coursesProvider);
    return dueTotal.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const EEmptyState(
        icon: Icons.cloud_off_outlined,
        title: "We couldn't load reviews",
        message: 'Your data is safe — please try again.',
      ),
      data: (total) {
        if (total == 0) {
          return EEmptyState(
            icon: Icons.check_circle_outline,
            title: 'All caught up ✓',
            message: 'Nothing is due for review right now. Learn something new or play a game.',
            primaryLabel: 'Learn',
            onPrimary: () => _openLessonPicker(context, ref),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => refreshAfterStudy(ref),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              EHeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$total item${total == 1 ? '' : 's'} ready for review',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Short review keeps words strong.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    EPrimaryButton(
                      label: 'Review Now',
                      icon: Icons.refresh,
                      onPressed: () => _openLessonPicker(context, ref),
                    ),
                  ],
                ),
              ),
              courses.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (list) => dueByLesson.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (byLesson) =>
                      _lessonGroups(context, ref, list, byLesson),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _lessonGroups(
    BuildContext context,
    WidgetRef ref,
    List<Course> courses,
    Map<String, int> byLesson,
  ) {
    return FutureBuilder(
      future: _groups(ref, courses, byLesson),
      builder: (ctx, snap) {
        final groups = snap.data ?? [];
        if (groups.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'Review by lesson',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final g in groups)
              ETile(
                icon: Icons.refresh,
                title: '${g.lessonTitle} · ${g.count} due',
                subtitle: g.courseTitle,
                onTap: () => LearnLessonLauncher.open(context, g.lessonId),
              ),
          ],
        );
      },
    );
  }

  Future<List<_DueGroup>> _groups(
    WidgetRef ref,
    List<Course> courses,
    Map<String, int> byLesson,
  ) async {
    final repo = ref.read(repositoryProvider);
    final out = <_DueGroup>[];
    for (final c in courses) {
      for (final l in await repo.lessonsOf(c.id)) {
        final count = byLesson[l.id] ?? 0;
        if (count > 0) {
          out.add(
            _DueGroup(
              courseTitle: c.title,
              lessonId: l.id,
              lessonTitle: l.title,
              count: count,
            ),
          );
        }
      }
    }
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  Future<void> _openLessonPicker(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    final courses = await repo.allLessons();
    if (courses.isEmpty) {
      if (context.mounted) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ImportScreen()));
      }
      return;
    }
    // Start with the lesson that has the most due items.
    final byLesson = await repo.dueCountsByLesson();
    String lessonId = courses.first.$2.id;
    var best = -1;
    for (final (_, lesson) in courses) {
      final count = byLesson[lesson.id] ?? 0;
      if (count > best) {
        best = count;
        lessonId = lesson.id;
      }
    }
    if (context.mounted) {
      LearnLessonLauncher.open(context, lessonId);
    }
  }
}

class _DueGroup {
  final String courseTitle;
  final String lessonId;
  final String lessonTitle;
  final int count;

  _DueGroup({
    required this.courseTitle,
    required this.lessonId,
    required this.lessonTitle,
    required this.count,
  });
}

/// Compatibility alias: old Courses tab imports resolve to Learn.
class PracticeCourseBridge {
  static Widget lessonDetail(String lessonId) =>
      LessonDetailScreen(lessonId: lessonId);
}
