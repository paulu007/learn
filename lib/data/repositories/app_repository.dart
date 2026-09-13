import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../database/app_database.dart';
import '../models/models.dart';

/// Single repository over the offline SQLite database.
/// Keeps UI and learning logic separate from storage details.
class AppRepository {
  final Future<Database> _db;
  AppRepository([Future<Database>? db]) : _db = db ?? AppDatabase.instance();

  // ---------- Settings ----------

  static const _kStreak = 'current_streak';
  static const _kLongest = 'longest_streak';
  static const _kLastDay = 'last_study_day';

  Future<UserSettings> loadSettings() async {
    final db = await _db;
    final rows = await db.query('settings');
    final map = {for (final r in rows) r['key'] as String: r['value'] as String?};
    return UserSettings.fromMap(map);
  }

  Future<void> saveSettings(UserSettings s) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in s.toMap().entries) {
      batch.insert('settings', {
        'key': e.key,
        'value': e.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ---------- Courses ----------

  Future<List<Course>> courses() async {
    final db = await _db;
    final rows = await db.query('courses', orderBy: 'created_at ASC');
    return rows.map(Course.fromMap).toList();
  }

  Future<Course?> courseById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'courses',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : Course.fromMap(rows.first);
  }

  Future<Course> createCourse(String sourceLang, String targetLang) async {
    final db = await _db;
    final course = Course.create(sourceLang, targetLang);
    await db.insert('courses', course.toMap());
    return course;
  }

  Future<void> renameCourse(String id, String source, String target) async {
    final db = await _db;
    await db.update(
      'courses',
      {'source_lang': source.trim(), 'target_lang': target.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setCurrentLesson(String courseId, String? lessonId) async {
    final db = await _db;
    await db.update(
      'courses',
      {'current_lesson_id': lessonId},
      where: 'id = ?',
      whereArgs: [courseId],
    );
  }

  Future<void> deleteCourse(String id) async {
    final db = await _db;
    // Manual cascade (works regardless of PRAGMA state).
    final lessons = await db.query(
      'lessons',
      columns: ['id'],
      where: 'course_id = ?',
      whereArgs: [id],
    );
    for (final l in lessons) {
      await _deleteLessonRows(db, l['id'] as String);
    }
    await db.delete('lessons', where: 'course_id = ?', whereArgs: [id]);
    await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Lessons ----------

  Future<List<Lesson>> lessonsOf(String courseId) async {
    final db = await _db;
    final rows = await db.query(
      'lessons',
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'order_index ASC',
    );
    return rows.map(Lesson.fromMap).toList();
  }

  Future<Lesson?> lessonById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'lessons',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : Lesson.fromMap(rows.first);
  }

  Future<Lesson> createLesson(String courseId, String title) async {
    final db = await _db;
    final existing = await lessonsOf(courseId);
    final lesson = Lesson.create(courseId, title, existing.length);
    await db.insert('lessons', lesson.toMap());
    return lesson;
  }

  Future<Lesson> findOrCreateLesson(
    String courseId,
    String title,
    int orderHint,
  ) async {
    final existing = await lessonsOf(courseId);
    final norm = title.trim().toLowerCase();
    for (final l in existing) {
      if (l.title.trim().toLowerCase() == norm) return l;
    }
    final db = await _db;
    final lesson = Lesson.create(
      courseId,
      title.trim(),
      existing.isEmpty ? orderHint : existing.length,
    );
    await db.insert('lessons', lesson.toMap());
    return lesson;
  }

  Future<void> renameLesson(String id, String title) async {
    final db = await _db;
    await db.update(
      'lessons',
      {'title': title.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Moves a lesson to [newIndex] within its course ordering.
  Future<void> moveLesson(String courseId, int oldIndex, int newIndex) async {
    final db = await _db;
    final lessons = await lessonsOf(courseId);
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= lessons.length ||
        newIndex >= lessons.length) {
      return;
    }
    final moved = lessons.removeAt(oldIndex);
    lessons.insert(newIndex, moved);
    final batch = db.batch();
    for (var i = 0; i < lessons.length; i++) {
      batch.update(
        'lessons',
        {'order_index': i},
        where: 'id = ?',
        whereArgs: [lessons[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Reset Progress: keep items, delete their progress rows.
  Future<void> resetLessonProgress(String lessonId) async {
    final db = await _db;
    final items = await db.query(
      'learning_items',
      columns: ['id'],
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
    );
    final batch = db.batch();
    for (final it in items) {
      batch.delete(
        'progress',
        where: 'item_id = ?',
        whereArgs: [it['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Clear Lesson: remove the lesson shell and all its content.
  Future<void> deleteLesson(String lessonId) async {
    final db = await _db;
    await _deleteLessonRows(db, lessonId);
    await db.delete('lessons', where: 'id = ?', whereArgs: [lessonId]);
  }

  Future<void> _deleteLessonRows(DatabaseExecutor db, String lessonId) async {
    final items = await db.query(
      'learning_items',
      columns: ['id'],
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
    );
    for (final it in items) {
      await db.delete(
        'progress',
        where: 'item_id = ?',
        whereArgs: [it['id']],
      );
    }
    await db.delete(
      'learning_items',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
    );
  }

  // ---------- Learning items ----------

  Future<void> insertItems(List<LearningItem> items) async {
    if (items.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final it in items) {
      batch.insert(
        'learning_items',
        it.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<LearningItem>> itemsOfLesson(String lessonId) async {
    final db = await _db;
    final rows = await db.query(
      'learning_items',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      orderBy: 'created_at ASC',
    );
    return rows.map(LearningItem.fromMap).toList();
  }

  Future<Map<String, int>> itemCountsByType(String lessonId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT type, COUNT(*) AS c FROM learning_items WHERE lesson_id = ? GROUP BY type',
      [lessonId],
    );
    return {for (final r in rows) (r['type'] as String): ((r['c'] as num)).toInt()};
  }

  /// Items due for review: never reviewed, or next_review reached.
  Future<List<LearningItem>> dueItems(String lessonId, {int limit = 50}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT li.* FROM learning_items li
      LEFT JOIN progress pr ON pr.item_id = li.id
      WHERE li.lesson_id = ?
        AND (pr.item_id IS NULL OR pr.next_review IS NULL OR pr.next_review <= ?)
      ORDER BY pr.last_reviewed ASC, li.created_at ASC
      LIMIT ?
      ''',
      [lessonId, nowMs(), limit],
    );
    return rows.map(LearningItem.fromMap).toList();
  }

  // ---------- Progress ----------

  Future<Map<String, ItemProgress>> progressForItems(
    List<String> itemIds,
  ) async {
    if (itemIds.isEmpty) return {};
    final db = await _db;
    final placeholders = List.filled(itemIds.length, '?').join(',');
    final rows = await db.query(
      'progress',
      where: 'item_id IN ($placeholders)',
      whereArgs: itemIds,
    );
    return {for (final r in rows) (r['item_id'] as String): ItemProgress.fromMap(r)};
  }

  Future<ItemProgress> getProgress(String itemId) async {
    final map = await progressForItems([itemId]);
    return map[itemId] ?? ItemProgress(itemId: itemId);
  }

  /// Records a self-grade [rating] (0 Again, 1 Hard, 2 Good, 3 Easy) and
  /// updates today's activity + streak. Returns the updated progress.
  Future<ItemProgress> rateItem(
    LearningItem item,
    int rating, {
    bool useHint = false,
  }) async {
    final db = await _db;
    final current = await getProgress(item.id);
    final updated = current.applyRating(
      useHint && rating > 0 ? rating - 1 : rating,
    );
    await db.insert(
      'progress',
      updated.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await recordActivity(
      word: item.isVocab,
      sentence: !item.isVocab,
    );
    return updated;
  }

  Future<Map<String, int>> statusCountsForLesson(String lessonId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(pr.status, 'new') AS s, COUNT(*) AS c
      FROM learning_items li LEFT JOIN progress pr ON pr.item_id = li.id
      WHERE li.lesson_id = ?
      GROUP BY s
      ''',
      [lessonId],
    );
    return {for (final r in rows) (r['s'] as String): ((r['c'] as num)).toInt()};
  }

  // ---------- Daily activity + streak ----------

  Future<DailyActivity> activityFor(String day) async {
    final db = await _db;
    final rows = await db.query(
      'daily_activity',
      where: 'day = ?',
      whereArgs: [day],
    );
    return rows.isEmpty
        ? DailyActivity(day: day)
        : DailyActivity.fromMap(rows.first);
  }

  Future<List<DailyActivity>> activityRange(String from, String to) async {
    final db = await _db;
    final rows = await db.query(
      'daily_activity',
      where: 'day >= ? AND day <= ?',
      whereArgs: [from, to],
      orderBy: 'day ASC',
    );
    return rows.map(DailyActivity.fromMap).toList();
  }

  /// Records one learning activity for today. When the daily goal is reached
  /// for the first time today, the streak is extended.
  Future<DailyActivity> recordActivity({
    bool word = false,
    bool sentence = false,
    bool game = false,
    int studySeconds = 0,
  }) async {
    final db = await _db;
    final today = dayKey();
    var activity = await activityFor(today);
    activity = activity
        .bump(word: word, sentence: sentence)
        .copyWith(
          gamesPlayed: activity.gamesPlayed + (game ? 1 : 0),
          studySeconds: activity.studySeconds + studySeconds,
        );

    final settings = await loadSettings();
    final goal = settings.dailyGoal <= 0
        ? AppConstants.defaultDailyGoal
        : settings.dailyGoal;
    if (!activity.goalCompleted && activity.activities >= goal) {
      activity = activity.copyWith(goalCompleted: true);
      await _extendStreak(db, today);
    }
    await db.insert(
      'daily_activity',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return activity;
  }

  Future<void> _extendStreak(Database db, String today) async {
    int current = int.tryParse(await _get(db, _kStreak) ?? '0') ?? 0;
    int longest = int.tryParse(await _get(db, _kLongest) ?? '0') ?? 0;
    final last = await _get(db, _kLastDay);
    if (last == today) return; // already counted today
    if (last == null || daysSince(DateTime.parse(last)) <= 1) {
      current = (last == null && current == 0) ? 1 : current + 1;
    } else {
      current = 1; // streak was broken
    }
    if (current > longest) longest = current;
    await _set(db, _kStreak, current.toString());
    await _set(db, _kLongest, longest.toString());
    await _set(db, _kLastDay, today);
  }

  Future<StreakInfo> streak() async {
    final db = await _db;
    final current = int.tryParse(await _get(db, _kStreak) ?? '0') ?? 0;
    final longest = int.tryParse(await _get(db, _kLongest) ?? '0') ?? 0;
    final last = await _get(db, _kLastDay);
    // A streak with no study yesterday or today is broken.
    var effective = current;
    if (last != null) {
      final gap = daysSince(DateTime.parse(last));
      if (gap > 1) effective = 0;
    } else {
      effective = 0;
    }
    return StreakInfo(
      current: effective,
      longest: longest,
      lastStudyDay: last,
    );
  }

  Future<String?> _get(DatabaseExecutor db, String key) async {
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _set(DatabaseExecutor db, String key, String value) async {
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- Game results ----------

  Future<void> saveGameResult({
    required String gameType,
    String? lessonId,
    required int correct,
    required int wrong,
    required int durationSeconds,
  }) async {
    final db = await _db;
    final total = correct + wrong;
    final score = total == 0 ? 0 : ((correct / total) * 100).round();
    await db.insert('game_results', {
      'id': newId(),
      'game_type': gameType,
      'lesson_id': lessonId,
      'correct': correct,
      'wrong': wrong,
      'score': score,
      'duration_seconds': durationSeconds,
      'played_at': nowMs(),
    });
    await recordActivity(game: true);
  }

  Future<int> bestScore(String gameType, {String? lessonId}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT MAX(score) AS b FROM game_results WHERE game_type = ?'
      '${lessonId == null ? '' : ' AND lesson_id = ?'}',
      lessonId == null ? [gameType] : [gameType, lessonId],
    );
    return ((rows.first['b'] as num?) ?? 0).toInt();
  }

  Future<List<Map<String, Object?>>> gameHistory({int limit = 50}) async {
    final db = await _db;
    return db.query(
      'game_results',
      orderBy: 'played_at DESC',
      limit: limit,
    );
  }

  // ---------- Statistics ----------

  /// Every lesson across all courses, newest course first.
  Future<List<(Course, Lesson)>> allLessons() async {
    final courses = await this.courses();
    final out = <(Course, Lesson)>[];
    for (final c in courses) {
      for (final l in await lessonsOf(c.id)) {
        out.add((c, l));
      }
    }
    return out;
  }

  /// Overall progress-status counts across all items.
  Future<Map<String, int>> overallStatusCounts() async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(pr.status, 'new') AS s, COUNT(*) AS c
      FROM learning_items li LEFT JOIN progress pr ON pr.item_id = li.id
      GROUP BY s
      ''',
    );
    return {for (final r in rows) (r['s'] as String): ((r['c'] as num)).toInt()};
  }

  /// Total study seconds logged across all days.
  Future<int> totalStudySeconds() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(study_seconds),0) AS s FROM daily_activity',
    );
    return ((rows.first['s'] as num?) ?? 0).toInt();
  }

  Future<Map<String, int>> totals() async {
    final db = await _db;
    Future<int> count(String table, [String? where]) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $table${where == null ? '' : ' WHERE $where'}',
      );
      return ((rows.first['c'] as num?) ?? 0).toInt();
    }

    final correctRows = await db.rawQuery(
      'SELECT COALESCE(SUM(correct_count),0) AS s, COALESCE(SUM(wrong_count),0) AS w FROM progress',
    );
    return {
      'courses': await count('courses'),
      'lessons': await count('lessons'),
      'items': await count('learning_items'),
      'vocab': await count('learning_items', "type = 'vocab'"),
      'sentences': await count(
        'learning_items',
        "type = 'sentence' OR type = 'communication'",
      ),
      'mastered': await count('progress', "status = 'mastered'"),
      'correct': ((correctRows.first['s'] as num?) ?? 0).toInt(),
      'wrong': ((correctRows.first['w'] as num?) ?? 0).toInt(),
    };
  }

  // ---------- Weak items / maintenance ----------

  /// Items where mistakes outnumber correct answers (for the Progress screen).
  Future<List<(LearningItem, ItemProgress)>> weakItems({
    int limit = 10,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT li.*, pr.item_id AS item_id, pr.status, pr.correct_count,
             pr.wrong_count, pr.last_reviewed, pr.next_review, pr.confidence
      FROM progress pr JOIN learning_items li ON li.id = pr.item_id
      WHERE pr.wrong_count > pr.correct_count
      ORDER BY (pr.wrong_count - pr.correct_count) DESC
      LIMIT ?
      ''',
      [limit],
    );
    return rows
        .map((r) => (LearningItem.fromMap(r), ItemProgress.fromMap(r)))
        .toList();
  }

  /// Danger zone: removes all learning progress but keeps content.
  Future<void> resetAllProgress() async {
    final db = await _db;
    await db.delete('progress');
  }

  /// Danger zone: removes every course, lesson, item and progress row.
  Future<void> clearAllContent() async {
    final db = await _db;
    await db.delete('progress');
    await db.delete('learning_items');
    await db.delete('lessons');
    await db.delete('courses');
  }

  // ---------- Backup / restore / export ----------

  Future<Map<String, Object?>> exportAll() async {
    final db = await _db;
    final tables = [
      'courses',
      'lessons',
      'learning_items',
      'progress',
      'daily_activity',
      'game_results',
      'settings',
    ];
    final data = <String, Object?>{};
    for (final t in tables) {
      data[t] = await db.query(t);
    }
    data['exported_at'] = nowMs();
    data['version'] = 1;
    return data;
  }

  Future<String> writeBackup() async {
    final data = await exportAll();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(dir.path, 'e_backup_${dayKey()}_${nowMs()}.json'),
    );
    await file.writeAsString(jsonEncode(data));
    return file.path;
  }

  Future<String> exportLesson(String lessonId) async {
    final lesson = await lessonById(lessonId);
    final items = await itemsOfLesson(lessonId);
    final buffer = StringBuffer(
      'type,source,target,example,hint,lesson,tags,difficulty\n',
    );
    String esc(String s) {
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }

    for (final it in items) {
      buffer.writeln(
        [
          it.type,
          esc(it.sourceText),
          esc(it.targetText),
          esc(it.example),
          esc(it.hint),
          esc(lesson?.title ?? ''),
          esc(it.tags),
          it.difficulty,
        ].join(','),
      );
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(dir.path, 'e_lesson_${lessonId.substring(0, 8)}.csv'),
    );
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  /// Restores everything from a backup file. Returns counts per table.
  Future<Map<String, int>> restoreBackup(String path) async {
    final db = await _db;
    final raw = await File(path).readAsString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    const tables = [
      'courses',
      'lessons',
      'learning_items',
      'progress',
      'daily_activity',
      'game_results',
      'settings',
    ];
    final counts = <String, int>{};
    await db.transaction((txn) async {
      for (final t in tables) {
        final rows = (data[t] as List?) ?? [];
        await txn.delete(t);
        final batch = txn.batch();
        for (final r in rows) {
          batch.insert(
            t,
            Map<String, Object?>.from(r as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        counts[t] = rows.length;
      }
    });
    return counts;
  }
}
