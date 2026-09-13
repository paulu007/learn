import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';
import '../courses/courses_screen.dart';
import '../import_data/import_screen.dart';
import '../learning/lesson_session_screen.dart';

/// Home: streak, today's goal/progress, current course + lesson,
/// continue learning, recently studied, shortcuts.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final activity = ref.watch(todayActivityProvider);
    final streak = ref.watch(streakProvider);
    final courses = ref.watch(coursesProvider);

    return settings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: e.toString(),
      ),
      data: (s) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coursesProvider);
          ref.invalidate(todayActivityProvider);
          ref.invalidate(streakProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                dayGreeting(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _streakCard(context, streak, s.dailyGoal),
            _todayCard(context, s.dailyGoal, activity),
            _continueCard(context, ref, courses, s),
            _shortcutsRow(context),
          ],
        ),
      ),
    );
  }

  Widget _streakCard(
    BuildContext context,
    AsyncValue<StreakInfo> streak,
    int goal,
  ) {
    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Colors.orange,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: streak.when(
              loading: () => const Text('Loading streak…'),
              error: (_, _) => const Text('Streak unavailable'),
              data: (st) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${st.current} Day Streak',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Longest: ${st.longest} days · Goal: $goal activities/day',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayCard(
    BuildContext context,
    int goal,
    AsyncValue<DailyActivity> activity,
  ) {
    return activity.when(
      loading: () => const SectionCard(child: LinearProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
      data: (act) {
        final done = act.activities.clamp(0, goal);
        final doneGoal = act.goalCompleted;
        return SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Today's Progress",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (doneGoal)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.correctGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          color: AppConstants.correctGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LabeledProgress(
                value: goal == 0 ? 0 : done / goal,
                label: '$done / $goal activities',
              ),
              if (doneGoal)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Daily Goal Complete! Streak updated.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppConstants.correctGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _continueCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Course>> courses,
    UserSettings s,
  ) {
    return courses.when(
      loading: () => const SectionCard(child: LinearProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
      data: (all) {
        if (all.isEmpty) {
          return SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to E!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Import your first lesson from a CSV or Excel file to start learning. Your language, your lessons, your pace.',
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Import Lesson',
                  icon: Icons.upload_file,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ImportScreen(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return FutureBuilder(
          future: _currentLesson(ref, all, s),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const SectionCard(
                child: LinearProgressIndicator(),
              );
            }
            final info = snap.data!;
            return SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Course:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    info.courseTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Lesson: ${info.lessonTitle}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Words: ${info.words} · Sentences: ${info.sentences}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (info.recent != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Recently studied: ${info.recent}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Continue Learning',
                    icon: Icons.play_arrow,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LessonSessionScreen(
                            lessonId: info.lessonId,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<_CurrentInfo> _currentLesson(
    WidgetRef ref,
    List<Course> all,
    UserSettings s,
  ) async {
    final repo = ref.read(repositoryProvider);
    var course = all.first;
    final lastCourseId = s.lastCourseId;
    final lastLessonId = s.lastLessonId;
    if (lastCourseId != null) {
      for (final c in all) {
        if (c.id == lastCourseId) course = c;
      }
    }
    final lessons = await repo.lessonsOf(course.id);
    if (lessons.isEmpty) {
      return _CurrentInfo(
        courseTitle: course.title,
        lessonTitle: 'No lessons yet',
        lessonId: '',
        words: 0,
        sentences: 0,
        recent: null,
      );
    }
    var lesson = lessons.first;
    if (lastLessonId != null) {
      for (final l in lessons) {
        if (l.id == lastLessonId) lesson = l;
      }
    } else if (course.currentLessonId != null) {
      for (final l in lessons) {
        if (l.id == course.currentLessonId) lesson = l;
      }
    }
    final counts = await repo.itemCountsByType(lesson.id);
    final recentLesson = lastLessonId == null
        ? null
        : await repo.lessonById(lastLessonId);
    return _CurrentInfo(
      courseTitle: course.title,
      lessonTitle: lesson.title,
      lessonId: lesson.id,
      words: counts['vocab'] ?? 0,
      sentences:
          (counts['sentence'] ?? 0) + (counts['communication'] ?? 0),
      recent: recentLesson?.title,
    );
  }

  Widget _shortcutsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _Shortcut(
              icon: Icons.school_outlined,
              label: 'Courses',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CoursesScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Shortcut(
              icon: Icons.upload_file_outlined,
              label: 'Import',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ImportScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentInfo {
  final String courseTitle;
  final String lessonTitle;
  final String lessonId;
  final int words;
  final int sentences;
  final String? recent;

  _CurrentInfo({
    required this.courseTitle,
    required this.lessonTitle,
    required this.lessonId,
    required this.words,
    required this.sentences,
    required this.recent,
  });
}
