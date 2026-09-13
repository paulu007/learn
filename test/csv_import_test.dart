import 'package:e/core/utils/app_utils.dart';
import 'package:e/data/import/csv_import.dart';
import 'package:e/data/models/models.dart';
import 'package:e/features/learning/learning_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvImportService', () {
    final service = CsvImportService();

    test('parses the documented example format', () {
      const csv =
          'type,source,target,example,hint,lesson,tags,difficulty\n'
          'vocab,hello,سلام,Hello John!,A greeting,1,greeting,easy\n'
          'sentence,How are you?,حالت چطوره؟,How are you today?,Common greeting,1,greetings,easy';
      final preview = service.parseCsv(csv);
      expect(preview.globalErrors, isEmpty);
      expect(preview.validRows.length, 2);
      expect(preview.lessons, ['1']);
      expect(preview.validRows.first.source, 'hello');
    });

    test('flags rows with problems but keeps valid rows', () {
      const csv =
          'type,source,target,example,hint,lesson,tags,difficulty\n'
          'vocab,book,کتاب,,,,,easy\n'
          'bogus,,missing,,,,,hard\n';
      final preview = service.parseCsv(csv);
      expect(preview.validRows.length, 1);
      expect(preview.invalidRows.length, 1);
      expect(preview.invalidRows.first.problems, isNotEmpty);
    });

    test('reports missing required columns', () {
      final preview = service.parseCsv('foo,bar\n1,2');
      expect(preview.globalErrors, isNotEmpty);
    });

    test('accepts header aliases', () {
      const csv =
          'Source Text,Translation,Lesson\nhello,سلام,Basics';
      final preview = service.parseCsv(csv);
      expect(preview.globalErrors, isEmpty);
      expect(preview.validRows.length, 1);
      expect(preview.validRows.first.type, 'vocab'); // defaulted
    });
  });

  group('ItemProgress.applyRating', () {
    test('Again keeps item in learning with near review', () {
      final p = const ItemProgress(itemId: 'x').applyRating(0);
      expect(p.status, 'learning');
      expect(p.wrongCount, 1);
      expect(p.nextReview, isNotNull);
    });

    test('repeated Good leads toward mastered', () {
      var p = const ItemProgress(itemId: 'x');
      for (var i = 0; i < 5; i++) {
        p = p.applyRating(2);
      }
      expect(p.status, 'mastered');
      expect(p.correctCount, 5);
    });
  });

  group('LearningService.checkAnswer', () {
    test('ignores case and whitespace', () {
      expect(LearningService.checkAnswer('I need water', '  i NEED  water '), isTrue);
      expect(LearningService.checkAnswer('book', 'table'), isFalse);
    });
  });

  group('hintFor', () {
    test('levels progress from category to answer', () {
      final item = LearningItem(
        id: '1',
        courseId: 'c',
        lessonId: 'l',
        type: 'vocab',
        sourceText: 'book',
        targetText: 'کتاب',
        example: 'I read a book.',
        hint: '',
        tags: 'objects',
        difficulty: 'easy',
        createdAt: 0,
      );
      expect(hintFor(item, 1).text, 'objects');
      expect(hintFor(item, 2).text, contains('read a book'));
      expect(hintFor(item, 3).text, contains('ک'));
      expect(hintFor(item, 4).text, 'کتاب');
    });
  });

  group('dayKey helpers', () {
    test('round-trips addDays', () {
      final today = dayKey();
      expect(addDays(addDays(today, 3), -3), today);
    });
  });
}
