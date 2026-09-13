import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Offline SQLite database. Uses the platform plugin on Android and
/// sqflite FFI on desktop (Windows/Linux/macOS).
class AppDatabase {
  static const _name = 'e_learning.db';
  static const version = 1;

  static Database? _db;
  static DatabaseFactory? _factoryOverride;

  /// Test hook: inject an in-memory factory.
  static void setFactoryForTest(DatabaseFactory factory) {
    _factoryOverride = factory;
  }

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final factory = _factoryOverride ?? await _resolveFactory();
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _name);
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
    return _db!;
  }

  static Future<DatabaseFactory> _resolveFactory() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE courses(
        id TEXT PRIMARY KEY,
        source_lang TEXT NOT NULL,
        target_lang TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        current_lesson_id TEXT
      )''');
    await db.execute('''
      CREATE TABLE lessons(
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        title TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
      )''');
    await db.execute('''
      CREATE TABLE learning_items(
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        type TEXT NOT NULL,
        source_text TEXT NOT NULL,
        target_text TEXT NOT NULL,
        example TEXT NOT NULL DEFAULT '',
        hint TEXT NOT NULL DEFAULT '',
        tags TEXT NOT NULL DEFAULT '',
        difficulty TEXT NOT NULL DEFAULT 'easy',
        created_at INTEGER NOT NULL,
        FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE,
        FOREIGN KEY(lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
      )''');
    await db.execute('''
      CREATE TABLE progress(
        item_id TEXT PRIMARY KEY,
        status TEXT NOT NULL DEFAULT 'new',
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        last_reviewed INTEGER,
        next_review INTEGER,
        confidence REAL NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE daily_activity(
        day TEXT PRIMARY KEY,
        activities INTEGER NOT NULL DEFAULT 0,
        words_learned INTEGER NOT NULL DEFAULT 0,
        sentences_learned INTEGER NOT NULL DEFAULT 0,
        games_played INTEGER NOT NULL DEFAULT 0,
        study_seconds INTEGER NOT NULL DEFAULT 0,
        goal_completed INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE game_results(
        id TEXT PRIMARY KEY,
        game_type TEXT NOT NULL,
        lesson_id TEXT,
        correct INTEGER NOT NULL,
        wrong INTEGER NOT NULL,
        score INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        played_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
    // Enable cascading deletes.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v1 is the first schema; future migrations go here.
  }
}
