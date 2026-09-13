import 'package:csv/csv.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../models/models.dart';

/// One validated row from a CSV/Excel import.
class ImportRow {
  final int lineNumber;
  final String type;
  final String source;
  final String target;
  final String example;
  final String hint;
  final String lesson;
  final String tags;
  final String difficulty;
  final List<String> problems;

  const ImportRow({
    required this.lineNumber,
    required this.type,
    required this.source,
    required this.target,
    this.example = '',
    this.hint = '',
    this.lesson = '',
    this.tags = '',
    this.difficulty = 'easy',
    this.problems = const [],
  });

  bool get valid => problems.isEmpty;
}

/// Result of parsing + validating a CSV file (Excel is converted to the
/// same row grid first, then validated here).
class ImportPreview {
  final List<ImportRow> rows;
  final List<String> globalErrors;

  const ImportPreview({this.rows = const [], this.globalErrors = const []});

  List<ImportRow> get validRows => rows.where((r) => r.valid).toList();
  List<ImportRow> get invalidRows => rows.where((r) => !r.valid).toList();

  /// Distinct lesson names in valid rows (in first-seen order).
  List<String> get lessons {
    final seen = <String>[];
    for (final r in validRows) {
      final name = r.lesson.isEmpty ? 'Lesson 1' : r.lesson;
      if (!seen.contains(name)) seen.add(name);
    }
    return seen;
  }
}

class CsvImportService {
  /// Header aliases so "Source Text", "SOURCE", etc. all map correctly.
  static const _aliases = <String, String>{
    'type': 'type',
    'kind': 'type',
    'source': 'source',
    'source_text': 'source',
    'sourcetext': 'source',
    'front': 'source',
    'target': 'target',
    'target_text': 'target',
    'targettext': 'target',
    'translation': 'target',
    'back': 'target',
    'example': 'example',
    'example_sentence': 'example',
    'hint': 'hint',
    'lesson': 'lesson',
    'lesson_name': 'lesson',
    'unit': 'lesson',
    'tags': 'tags',
    'tag': 'tags',
    'category': 'tags',
    'difficulty': 'difficulty',
    'level': 'difficulty',
  };

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');

  static String _canon(String header) {
    final n = _norm(header);
    // Try compact match first, then raw lowered match.
    return _aliases[n] ?? _aliases[header.trim().toLowerCase()] ?? '';
  }

  /// Parses CSV text into an [ImportPreview]. Never throws: file-level
  /// problems land in [ImportPreview.globalErrors].
  ImportPreview parseCsv(String text) {
    List<List<dynamic>> grid;
    try {
      grid = Csv().decode(text);
    } catch (e) {
      return ImportPreview(globalErrors: ['Could not parse the CSV file: $e']);
    }
    // Drop fully-empty rows.
    final lines = grid
        .where((r) => r.any((c) => c.toString().trim().isNotEmpty))
        .toList();
    if (lines.isEmpty) {
      return const ImportPreview(globalErrors: ['The file is empty.']);
    }
    return _validate(lines, startLine: 1);
  }

  /// Validates a string grid whose first row is the header. Used for Excel
  /// sheets converted to rows.
  ImportPreview parseGrid(List<List<String>> grid) {
    final lines = grid
        .where((r) => r.any((c) => c.trim().isNotEmpty))
        .map((r) => r.map((c) => c as dynamic).toList())
        .toList();
    if (lines.isEmpty) {
      return const ImportPreview(globalErrors: ['The sheet is empty.']);
    }
    return _validate(lines, startLine: 1);
  }

  ImportPreview _validate(List<List<dynamic>> lines, {int startLine = 1}) {
    final headerCells = lines.first.map((c) => c.toString()).toList();
    final indexOf = <String, int>{};
    for (var i = 0; i < headerCells.length; i++) {
      final canon = _canon(headerCells[i]);
      if (canon.isNotEmpty && !indexOf.containsKey(canon)) {
        indexOf[canon] = i;
      }
    }
    final missing = <String>[];
    for (final required in ['source', 'target']) {
      if (!indexOf.containsKey(required)) missing.add(required);
    }
    if (missing.isNotEmpty) {
      return ImportPreview(
        globalErrors: [
          'Missing required column(s): ${missing.join(', ')}. '
              'Expected headers: ${AppConstants.csvHeaders.join(', ')}.',
        ],
      );
    }

    String cell(List<dynamic> row, String key) {
      final i = indexOf[key];
      if (i == null || i >= row.length) return '';
      return row[i].toString().trim();
    }

    final rows = <ImportRow>[];
    for (var r = 1; r < lines.length; r++) {
      final line = lines[r];
      final problems = <String>[];
      var type = cell(line, 'type').toLowerCase();
      if (type.isEmpty) {
        type = 'vocab'; // default when omitted
      } else if (!AppConstants.itemTypes.contains(type)) {
        problems.add(
          'Unknown type "$type". Use: ${AppConstants.itemTypes.join(', ')}.',
        );
      }
      final source = cell(line, 'source');
      final target = cell(line, 'target');
      if (source.isEmpty) problems.add('Missing source text.');
      if (target.isEmpty) problems.add('Missing target translation.');
      var difficulty = cell(line, 'difficulty').toLowerCase();
      if (difficulty.isEmpty) {
        difficulty = 'easy';
      } else if (!AppConstants.difficulties.contains(difficulty)) {
        problems.add(
          'Unknown difficulty "$difficulty". Use: ${AppConstants.difficulties.join(', ')}.',
        );
        difficulty = 'easy';
      }
      rows.add(
        ImportRow(
          lineNumber: startLine + r,
          type: type,
          source: source,
          target: target,
          example: cell(line, 'example'),
          hint: cell(line, 'hint'),
          lesson: cell(line, 'lesson'),
          tags: cell(line, 'tags'),
          difficulty: difficulty,
          problems: problems,
        ),
      );
    }
    return ImportPreview(rows: rows);
  }

  /// Builds unsaved [LearningItem]s grouped by lesson name. The caller
  /// creates the course/lessons then inserts via the repository.
  Map<String, List<LearningItem>> groupByLesson(
    String courseId,
    Map<String, String> lessonIds,
    List<ImportRow> validRows,
  ) {
    final grouped = <String, List<LearningItem>>{};
    for (final r in validRows) {
      final lessonName = r.lesson.isEmpty ? 'Lesson 1' : r.lesson;
      final lessonId = lessonIds[lessonName];
      if (lessonId == null) continue;
      grouped
          .putIfAbsent(lessonName, () => [])
          .add(
            LearningItem(
              id: newId(),
              courseId: courseId,
              lessonId: lessonId,
              type: r.type,
              sourceText: r.source,
              targetText: r.target,
              example: r.example,
              hint: r.hint,
              tags: r.tags,
              difficulty: r.difficulty,
              createdAt: nowMs(),
            ),
          );
    }
    return grouped;
  }
}
