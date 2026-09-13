import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/design/e_design.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';
import '../courses/lesson_detail_screen.dart';
import '../games/games_screen.dart';
import '../import_data/import_screen.dart';
import '../learn/learn_screen.dart';
import '../learning/lesson_session_screen.dart';
import '../practice/practice_screen.dart';

/// Home (spec §8, §58, §59): answers "What should I do now?"
/// Greeting → streak → daily goal → continue → review → quick actions.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return EAsyncView<UserSettings>(
      value: settings,
      builder: (s) => RefreshIndicator(
        onRefresh: () async => refreshAfterStudy(ref),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _greeting(context, ref),
            _continueHero(context, ref, s),
            _reviewHero(context, ref),
            _todayRow(context, ref, s.dailyGoal),
            _quickActions(context),
          ],
        ),
      ),
    );
  }

  Widget _greeting(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dayGreeting()} 👋',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'What should you do now? Start below.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          streak.maybeWhen(
            data: (st) => EStreakPill(days: st.current),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Smart Continue (spec §58): review due first, else current lesson.
  Widget _continueHero(BuildContext context, WidgetRef ref, UserSettings s) {
    final due = ref.watch(dueCountProvider);
    final courses = ref.watch(coursesProvider);
    return due.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (dueCount) {
        if (dueCount > 0) {
          return EHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Continue Learning',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review $dueCount word${dueCount == 1 ? '' : 's'} · ~5 minutes',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                EPrimaryButton(
                  label: 'Start',
                  icon: Icons.play_arrow,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PracticeScreen()),
                  ),
                ),
              ],
            ),
          );
        }
        return courses.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (all) {
            if (all.isEmpty) {
              return EHeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to E!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Import your first lesson to start learning. Your language, your lessons, your pace.',
                    ),
                    const SizedBox(height: 12),
                    EPrimaryButton(
                      label: 'Import Lesson',
                      icon: Icons.upload_file,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ImportScreen()),
                      ),
                    ),
                  ],
                ),
              );
            }
            return FutureBuilder(
              future: _currentLesson(ref, all, s),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final info = snap.data!;
                if (info.lessonId.isEmpty) return const SizedBox.shrink();
                return EHeroCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LessonDetailScreen(lessonId: info.lessonId),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue Learning',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.courseTitle,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${info.lessonTitle} · ${info.words} words · ${info.sentences} sentences',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      EPrimaryButton(
                        label: 'Continue',
                        icon: Icons.play_arrow,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LessonSessionScreen(lessonId: info.lessonId),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Daily review nudge (spec §35) — hidden when the Continue hero already
  /// covers review, shown when there is a current lesson AND due items.
  Widget _reviewHero(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueCountProvider);
    return due.maybeWhen(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return ESectionCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: EColors.xp.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(ERadii.lg),
                ),
                child: const Icon(Icons.history, color: EColors.xp, size: 26),
              ),
              const SizedBox(width: ESpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count ready for review',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      "Let's make them stronger.",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PracticeScreen()),
                ),
                child: const Text('Review'),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _todayRow(BuildContext context, WidgetRef ref, int goal) {
    final activity = ref.watch(todayActivityProvider);
    return activity.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (act) {
        final done = act.activities.clamp(0, goal);
        return ESectionCard(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const PracticeScreen())),
          child: Row(
            children: [
              EProgressRing(
                value: goal == 0 ? 0 : done / goal,
                done: done,
                goal: goal,
              ),
              const SizedBox(width: ESpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's goal",
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      act.goalCompleted
                          ? 'Completed ✓ — streak updated.'
                          : '$done of $goal activities done.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _quickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            'Quick actions',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ETile(
          icon: Icons.school_outlined,
          title: 'Learn',
          subtitle: 'Courses and lessons',
          onTap: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LearnScreen())),
        ),
        ETile(
          icon: Icons.sports_esports_outlined,
          title: 'Games',
          subtitle: 'Flash challenge, match, quick answer',
          onTap: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const GamesScreen())),
        ),
        ETile(
          icon: Icons.upload_file_outlined,
          title: 'Import',
          subtitle: 'CSV or Excel lessons',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ImportScreen())),
        ),
      ],
    );
  }

  Future<_CurrentInfo> _currentLesson(
    WidgetRef ref,
    List<Course> all,
    UserSettings s,
  ) async {
    final repo = ref.read(repositoryProvider);
    var course = all.first;
    if (s.lastCourseId != null) {
      for (final c in all) {
        if (c.id == s.lastCourseId) course = c;
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
      );
    }
    var lesson = lessons.first;
    if (s.lastLessonId != null) {
      for (final l in lessons) {
        if (l.id == s.lastLessonId) lesson = l;
      }
    } else if (course.currentLessonId != null) {
      for (final l in lessons) {
        if (l.id == course.currentLessonId) lesson = l;
      }
    }
    final counts = await repo.itemCountsByType(lesson.id);
    return _CurrentInfo(
      courseTitle: course.title,
      lessonTitle: lesson.title,
      lessonId: lesson.id,
      words: counts['vocab'] ?? 0,
      sentences: (counts['sentence'] ?? 0) + (counts['communication'] ?? 0),
    );
  }
}

class _CurrentInfo {
  final String courseTitle;
  final String lessonTitle;
  final String lessonId;
  final int words;
  final int sentences;

  _CurrentInfo({
    required this.courseTitle,
    required this.lessonTitle,
    required this.lessonId,
    required this.words,
    required this.sentences,
  });
}
