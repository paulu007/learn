// Data models for the E app. All models support toMap/fromMap for SQLite
// storage.

import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';

class Course {
  final String id;
  final String sourceLang;
  final String targetLang;
  final int createdAt;
  final String? currentLessonId;

  const Course({
    required this.id,
    required this.sourceLang,
    required this.targetLang,
    required this.createdAt,
    this.currentLessonId,
  });

  String get title => '$sourceLang → $targetLang';

  factory Course.create(String sourceLang, String targetLang) => Course(
    id: newId(),
    sourceLang: sourceLang.trim(),
    targetLang: targetLang.trim(),
    createdAt: nowMs(),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'source_lang': sourceLang,
    'target_lang': targetLang,
    'created_at': createdAt,
    'current_lesson_id': currentLessonId,
  };

  factory Course.fromMap(Map<String, Object?> m) => Course(
    id: m['id'] as String,
    sourceLang: m['source_lang'] as String,
    targetLang: m['target_lang'] as String,
    createdAt: m['created_at'] as int,
    currentLessonId: m['current_lesson_id'] as String?,
  );
}

class Lesson {
  final String id;
  final String courseId;
  final String title;
  final int orderIndex;
  final int createdAt;

  const Lesson({
    required this.id,
    required this.courseId,
    required this.title,
    required this.orderIndex,
    required this.createdAt,
  });

  factory Lesson.create(String courseId, String title, int orderIndex) =>
      Lesson(
        id: newId(),
        courseId: courseId,
        title: title.trim(),
        orderIndex: orderIndex,
        createdAt: nowMs(),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'course_id': courseId,
    'title': title,
    'order_index': orderIndex,
    'created_at': createdAt,
  };

  factory Lesson.fromMap(Map<String, Object?> m) => Lesson(
    id: m['id'] as String,
    courseId: m['course_id'] as String,
    title: m['title'] as String,
    orderIndex: (m['order_index'] as num).toInt(),
    createdAt: m['created_at'] as int,
  );
}

class LearningItem {
  final String id;
  final String courseId;
  final String lessonId;
  final String type; // vocab | sentence | communication
  final String sourceText;
  final String targetText;
  final String example;
  final String hint;
  final String tags;
  final String difficulty; // easy | medium | hard
  final int createdAt;

  const LearningItem({
    required this.id,
    required this.courseId,
    required this.lessonId,
    required this.type,
    required this.sourceText,
    required this.targetText,
    this.example = '',
    this.hint = '',
    this.tags = '',
    this.difficulty = 'easy',
    required this.createdAt,
  });

  bool get isVocab => type == 'vocab';
  bool get isSentence => type == 'sentence';

  Map<String, Object?> toMap() => {
    'id': id,
    'course_id': courseId,
    'lesson_id': lessonId,
    'type': type,
    'source_text': sourceText,
    'target_text': targetText,
    'example': example,
    'hint': hint,
    'tags': tags,
    'difficulty': difficulty,
    'created_at': createdAt,
  };

  factory LearningItem.fromMap(Map<String, Object?> m) => LearningItem(
    id: m['id'] as String,
    courseId: m['course_id'] as String,
    lessonId: m['lesson_id'] as String,
    type: m['type'] as String,
    sourceText: m['source_text'] as String,
    targetText: m['target_text'] as String,
    example: (m['example'] as String?) ?? '',
    hint: (m['hint'] as String?) ?? '',
    tags: (m['tags'] as String?) ?? '',
    difficulty: (m['difficulty'] as String?) ?? 'easy',
    createdAt: m['created_at'] as int,
  );
}

class ItemProgress {
  final String itemId;
  final String status; // new | learning | review | mastered
  final int correctCount;
  final int wrongCount;
  final int? lastReviewed;
  final int? nextReview;
  final double confidence; // 0.0 - 1.0

  const ItemProgress({
    required this.itemId,
    this.status = 'new',
    this.correctCount = 0,
    this.wrongCount = 0,
    this.lastReviewed,
    this.nextReview,
    this.confidence = 0.0,
  });

  ItemProgress copyWith({
    String? status,
    int? correctCount,
    int? wrongCount,
    int? lastReviewed,
    int? nextReview,
    double? confidence,
  }) => ItemProgress(
    itemId: itemId,
    status: status ?? this.status,
    correctCount: correctCount ?? this.correctCount,
    wrongCount: wrongCount ?? this.wrongCount,
    lastReviewed: lastReviewed ?? this.lastReviewed,
    nextReview: nextReview ?? this.nextReview,
    confidence: confidence ?? this.confidence,
  );

  /// Applies an SM-2-inspired update from a self-grade [rating]:
  /// 0 = Again, 1 = Hard, 2 = Good, 3 = Easy.
  ItemProgress applyRating(int rating) {
    final now = nowMs();
    final correct = rating >= 2;
    final newCorrect = correctCount + (correct ? 1 : 0);
    final newWrong = wrongCount + (correct ? 0 : 1);
    final total = newCorrect + newWrong;
    final conf = total == 0 ? 0.0 : newCorrect / total;

    String newStatus;
    int intervalDays;
    if (rating == 0) {
      newStatus = 'learning';
      intervalDays = 1;
    } else if (rating == 1) {
      newStatus = 'learning';
      intervalDays = status == 'new' ? 1 : 3;
    } else if (rating == 2) {
      newStatus = conf >= 0.85 && total >= 4 ? 'mastered' : 'review';
      intervalDays = status == 'mastered' ? 14 : (status == 'new' ? 1 : 4);
    } else {
      newStatus = total >= 2 ? 'mastered' : 'review';
      intervalDays = status == 'new' ? 3 : 7;
    }
    // Guard against unknown stored statuses.
    if (!AppConstants.progressStatuses.contains(newStatus)) {
      newStatus = 'learning';
    }
    return copyWith(
      status: newStatus,
      correctCount: newCorrect,
      wrongCount: newWrong,
      lastReviewed: now,
      nextReview: DateTime.now()
          .add(Duration(days: intervalDays))
          .millisecondsSinceEpoch,
      confidence: conf,
    );
  }

  Map<String, Object?> toMap() => {
    'item_id': itemId,
    'status': status,
    'correct_count': correctCount,
    'wrong_count': wrongCount,
    'last_reviewed': lastReviewed,
    'next_review': nextReview,
    'confidence': confidence,
  };

  factory ItemProgress.fromMap(Map<String, Object?> m) => ItemProgress(
    itemId: m['item_id'] as String,
    status: (m['status'] as String?) ?? 'new',
    correctCount: ((m['correct_count'] as num?) ?? 0).toInt(),
    wrongCount: ((m['wrong_count'] as num?) ?? 0).toInt(),
    lastReviewed: m['last_reviewed'] as int?,
    nextReview: m['next_review'] as int?,
    confidence: ((m['confidence'] as num?) ?? 0).toDouble(),
  );
}

class DailyActivity {
  final String day; // yyyy-MM-dd
  final int activities;
  final int wordsLearned;
  final int sentencesLearned;
  final int gamesPlayed;
  final int studySeconds;
  final bool goalCompleted;

  const DailyActivity({
    required this.day,
    this.activities = 0,
    this.wordsLearned = 0,
    this.sentencesLearned = 0,
    this.gamesPlayed = 0,
    this.studySeconds = 0,
    this.goalCompleted = false,
  });

  DailyActivity bump({bool word = false, bool sentence = false}) =>
      DailyActivity(
        day: day,
        activities: activities + 1,
        wordsLearned: wordsLearned + (word ? 1 : 0),
        sentencesLearned: sentencesLearned + (sentence ? 1 : 0),
        gamesPlayed: gamesPlayed,
        studySeconds: studySeconds,
        goalCompleted: goalCompleted,
      );

  DailyActivity copyWith({
    int? activities,
    int? wordsLearned,
    int? sentencesLearned,
    int? gamesPlayed,
    int? studySeconds,
    bool? goalCompleted,
  }) => DailyActivity(
    day: day,
    activities: activities ?? this.activities,
    wordsLearned: wordsLearned ?? this.wordsLearned,
    sentencesLearned: sentencesLearned ?? this.sentencesLearned,
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    studySeconds: studySeconds ?? this.studySeconds,
    goalCompleted: goalCompleted ?? this.goalCompleted,
  );

  Map<String, Object?> toMap() => {
    'day': day,
    'activities': activities,
    'words_learned': wordsLearned,
    'sentences_learned': sentencesLearned,
    'games_played': gamesPlayed,
    'study_seconds': studySeconds,
    'goal_completed': goalCompleted ? 1 : 0,
  };

  factory DailyActivity.fromMap(Map<String, Object?> m) => DailyActivity(
    day: m['day'] as String,
    activities: ((m['activities'] as num?) ?? 0).toInt(),
    wordsLearned: ((m['words_learned'] as num?) ?? 0).toInt(),
    sentencesLearned: ((m['sentences_learned'] as num?) ?? 0).toInt(),
    gamesPlayed: ((m['games_played'] as num?) ?? 0).toInt(),
    studySeconds: ((m['study_seconds'] as num?) ?? 0).toInt(),
    goalCompleted: ((m['goal_completed'] as num?) ?? 0).toInt() == 1,
  );
}

/// Streak info derived from daily-activity rows. Stored as settings keys
/// (current_streak, longest_streak, last_study_day) updated by the repo.
class StreakInfo {
  final int current;
  final int longest;
  final String? lastStudyDay;

  const StreakInfo({this.current = 0, this.longest = 0, this.lastStudyDay});
}

class UserSettings {
  final String themeMode; // light | dark | system
  final String fontSize; // small | normal | large | extraLarge
  final int dailyGoal;
  final String? lastCourseId;
  final String? lastLessonId;

  const UserSettings({
    this.themeMode = 'system',
    this.fontSize = 'normal',
    this.dailyGoal = 10,
    this.lastCourseId,
    this.lastLessonId,
  });

  UserSettings copyWith({
    String? themeMode,
    String? fontSize,
    int? dailyGoal,
    String? lastCourseId,
    String? lastLessonId,
    bool clearLesson = false,
  }) => UserSettings(
    themeMode: themeMode ?? this.themeMode,
    fontSize: fontSize ?? this.fontSize,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    lastCourseId: lastCourseId ?? this.lastCourseId,
    lastLessonId: clearLesson ? null : (lastLessonId ?? this.lastLessonId),
  );

  Map<String, String?> toMap() => {
    'theme_mode': themeMode,
    'font_size': fontSize,
    'daily_goal': dailyGoal.toString(),
    'last_course_id': lastCourseId,
    'last_lesson_id': lastLessonId,
  };

  factory UserSettings.fromMap(Map<String, String?> m) => UserSettings(
    themeMode: m['theme_mode'] ?? 'system',
    fontSize: m['font_size'] ?? 'normal',
    dailyGoal:
        int.tryParse(m['daily_goal'] ?? '') ??
        AppConstants.defaultDailyGoal,
    lastCourseId: m['last_course_id'],
    lastLessonId: m['last_lesson_id'],
  );
}
