import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_utils.dart';
import 'data/models/models.dart';
import 'data/repositories/app_repository.dart';

final repositoryProvider = Provider<AppRepository>((ref) => AppRepository());

// ---------- Settings ----------

class SettingsNotifier extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    return ref.watch(repositoryProvider).loadSettings();
  }

  Future<void> save(UserSettings s) async {
    await ref.read(repositoryProvider).saveSettings(s);
    state = AsyncValue.data(s);
  }

  Future<void> setTheme(String mode) async {
    final s = (await future).copyWith(themeMode: mode);
    await save(s);
  }

  Future<void> setFontSize(AppFontSize size) async {
    final s = (await future).copyWith(fontSize: size.name);
    await save(s);
  }

  Future<void> setDailyGoal(int goal) async {
    final s = (await future).copyWith(dailyGoal: goal);
    await save(s);
  }

  Future<void> setLastLesson(String? courseId, String? lessonId) async {
    final current = await future;
    final s = lessonId == null
        ? current.copyWith(clearLesson: true)
        : current.copyWith(lastCourseId: courseId, lastLessonId: lessonId);
    await save(s);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, UserSettings>(
  SettingsNotifier.new,
);

ThemeMode themeModeOf(String mode) => switch (mode) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

// ---------- Courses & lessons ----------

final coursesProvider = FutureProvider<List<Course>>((ref) async {
  return ref.watch(repositoryProvider).courses();
});

final lessonsProvider = FutureProvider.family<List<Lesson>, String>((
  ref,
  courseId,
) async {
  return ref.watch(repositoryProvider).lessonsOf(courseId);
});

final lessonItemsProvider = FutureProvider.family<List<LearningItem>, String>((
  ref,
  lessonId,
) async {
  return ref.watch(repositoryProvider).itemsOfLesson(lessonId);
});

final typeCountsProvider = FutureProvider.family<Map<String, int>, String>((
  ref,
  lessonId,
) async {
  return ref.watch(repositoryProvider).itemCountsByType(lessonId);
});

final statusCountsProvider = FutureProvider.family<Map<String, int>, String>((
  ref,
  lessonId,
) async {
  return ref.watch(repositoryProvider).statusCountsForLesson(lessonId);
});

final lessonOfProvider = FutureProvider.family<Lesson?, String>((
  ref,
  lessonId,
) async {
  return ref.watch(repositoryProvider).lessonById(lessonId);
});

final courseOfProvider = FutureProvider.family<Course?, String>((
  ref,
  courseId,
) async {
  return ref.watch(repositoryProvider).courseById(courseId);
});

// ---------- Activity / streak / totals ----------

final todayActivityProvider = FutureProvider<DailyActivity>((ref) async {
  return ref.watch(repositoryProvider).activityFor(dayKey());
});

final streakProvider = FutureProvider<StreakInfo>((ref) async {
  return ref.watch(repositoryProvider).streak();
});

final totalsProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.watch(repositoryProvider).totals();
});

final activityMonthProvider =
    FutureProvider.family<List<DailyActivity>, DateTime>((ref, month) async {
      final repo = ref.watch(repositoryProvider);
      final first = DateTime(month.year, month.month, 1);
      final last = DateTime(month.year, month.month + 1, 0);
      return repo.activityRange(dayKey(first), dayKey(last));
    });

/// Refresh everything that depends on learning activity.
void refreshAfterStudy(WidgetRef ref) {
  ref.invalidate(todayActivityProvider);
  ref.invalidate(streakProvider);
  ref.invalidate(totalsProvider);
  ref.invalidate(coursesProvider);
}

/// Text scaler applied at the app root from settings.
double fontScaleOf(UserSettings s) =>
    AppFontSize.fromName(s.fontSize).scale;

/// Light/dark ThemeData pair built from the current font size.
({ThemeData light, ThemeData dark}) themesOf(UserSettings s) {
  final scale = fontScaleOf(s);
  return (light: AppTheme.light(scale), dark: AppTheme.dark(scale));
}
