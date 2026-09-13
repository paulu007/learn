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

/// Home (mockup Screen 3 + spec §8, §58, §59): greeting + sun-yellow
/// streak pill → Today's Progress hero card with ring → Continue
/// Learning (dark navy) → Current Course → Review list.
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
            _todayHero(context, ref, s.dailyGoal),
            _continueDark(context, ref, s),
            _courseCard(context, ref, s),
            _reviewList(context, ref),
            _quickActions(context),
          ],
        ),
      ),
    );
  }

  Widget _greeting(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dayGreeting()} 👋',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ESpacing.sm),
          streak.maybeWhen(
            data: (st) => EStreakPill(days: st.current),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Mockup "Today's Progress" hero: 75%-style ring on the right,
  /// "15 / 20 activities" caption, full-width blue Continue CTA.
  Widget _todayHero(BuildContext context, WidgetRef ref, int goal) {
    final activity = ref.watch(todayActivityProvider);
    return activity.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (act) {
        final done = act.activities.clamp(0, goal);
        final frac = goal == 0 ? 0.0 : done / goal;
        return EHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Progress",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$done / $goal activities',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (act.goalCompleted)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Completed ✓ — streak updated.',
                              style: TextStyle(
                                color: EColors.leaf,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  EProgressRing(value: frac, done: done, goal: goal, size: 92),
                ],
              ),
              const SizedBox(height: ESpacing.lg),
              EPrimaryButton(
                label: 'Continue Learning',
                icon: Icons.play_arrow,
                onPressed: () => _openContinue(context, ref),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Smart Continue target (spec §58): most-due review lesson, else the
  /// current lesson, else Learn.
  Future<void> _openContinue(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    final byLesson = await repo.dueCountsByLesson();
    if (byLesson.isNotEmpty) {
      final top = byLesson.entries.reduce((a, b) => a.value >= b.value ? a : b);
      if (context.mounted) LearnLessonLauncher.open(context, top.key);
      return;
    }
    final settings = await ref.read(settingsProvider.future);
    final courses = await repo.courses();
    if (courses.isEmpty) {
      if (context.mounted) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const LearnScreen()));
      }
      return;
    }
    final info = await _currentLesson(ref, courses, settings);
    if (!context.mounted) return;
    if (info.lessonId.isEmpty) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LearnScreen()));
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonSessionScreen(lessonId: info.lessonId),
        ),
      );
    }
  }

  /// Mockup dark-navy "Continue Learning" card: lesson eyebrow, big
  /// title, meta line, full-width sky-blue action.
  Widget _continueDark(BuildContext context, WidgetRef ref, UserSettings s) {
    final courses = ref.watch(coursesProvider);
    return courses.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (all) {
        if (all.isEmpty) {
          return EDarkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to E!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Import your first lesson to start learning.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: ESpacing.lg),
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
            return EDarkCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LessonDetailScreen(lessonId: info.lessonId),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continue Learning'.toUpperCase(),
                    style: TextStyle(
                      color: EColors.sun,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    info.lessonTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${info.courseTitle} · ${info.words} words · ${info.sentences} sentences',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: ESpacing.lg),
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
  }

  /// Mockup "Current Course" card: label, pair title, lesson + counts,
  /// tappable through to the lesson.
  Widget _courseCard(BuildContext context, WidgetRef ref, UserSettings s) {
    final courses = ref.watch(coursesProvider);
    return courses.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (all) {
        if (all.isEmpty) return const SizedBox.shrink();
        return FutureBuilder(
          future: _currentLesson(ref, all, s),
          builder: (ctx, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final info = snap.data!;
            if (info.lessonId.isEmpty) return const SizedBox.shrink();
            return EHeroCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LessonDetailScreen(lessonId: info.lessonId),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Course'.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    info.courseTitle,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${info.lessonTitle} · ${info.words} words · ${info.sentences} sentences',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Mockup "Review" list: header + first due words with translations,
  /// footer Review Now CTA opening Practice.
  Widget _reviewList(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueCountProvider);
    return due.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Review',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '$count ready — make them stronger.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FutureBuilder(
              future: _reviewSample(ref, count),
              builder: (ctx, snap) {
                final rows = snap.data ?? [];
                return Column(
                  children: [
                    for (final r in rows)
                      EReviewRow(word: r.$1, translation: r.$2, done: false),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: EPrimaryButton(
                        label: 'Review Now',
                        icon: Icons.refresh,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PracticeScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// First few due words (source → target) for the mockup review list.
  Future<List<(String, String)>> _reviewSample(WidgetRef ref, int count) async {
    final repo = ref.read(repositoryProvider);
    final byLesson = await repo.dueCountsByLesson();
    final out = <(String, String)>[];
    for (final entry in byLesson.entries) {
      if (out.length >= 3) break;
      final items = await repo.dueItems(entry.key, limit: 3 - out.length);
      for (final it in items) {
        out.add((it.sourceText, it.targetText));
      }
    }
    return out;
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
                ?.copyWith(fontWeight: FontWeight.w800),
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
