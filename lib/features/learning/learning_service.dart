import 'dart:math';

import '../../data/models/models.dart';

/// Pure learning logic, kept out of widgets per the app architecture
/// (UI → State → LearningService → Repository → Database).
enum ExerciseKind { flashcard, multipleChoice, typing, sentenceBuilder }

class Exercise {
  final ExerciseKind kind;
  final LearningItem item;
  final List<String> choices; // multiple choice options (target texts)
  final List<String> shuffledWords; // sentence builder tiles

  const Exercise({
    required this.kind,
    required this.item,
    this.choices = const [],
    this.shuffledWords = const [],
  });
}

ClassHint hintFor(LearningItem item, int level) => ClassHint._(item, level);

class ClassHint {
  final String title;
  final String text;
  ClassHint._(LearningItem item, int level)
    : title = switch (level) {
        1 => 'Hint 1 — Category',
        2 => 'Hint 2 — Example',
        3 => 'Hint 3 — First letter',
        _ => 'Hint 4 — Answer',
      },
      text = switch (level) {
        1 => item.tags.isEmpty ? 'No category set.' : item.tags,
        2 => item.example.isEmpty ? 'No example available.' : item.example,
        3 => item.targetText.trim().isEmpty
            ? 'No answer available.'
            : 'Starts with "${String.fromCharCode(item.targetText.trim().runes.first)}".',
        _ => item.targetText,
      };
}

class LearningService {
  final Random _random;
  LearningService([Random? random]) : _random = random ?? Random();

  /// Builds a mixed exercise queue: flashcards first for new items, then a
  /// mix of multiple choice, typing, and sentence builder.
  List<Exercise> buildQueue(
    List<LearningItem> items,
    Map<String, ItemProgress> progress,
  ) {
    final queue = <Exercise>[];
    final shuffled = [...items]..shuffle(_random);
    for (final item in shuffled) {
      final status = progress[item.id]?.status ?? 'new';
      if (status == 'new') {
        queue.add(Exercise(kind: ExerciseKind.flashcard, item: item));
      }
      final kind = _pickKind(item);
      queue.add(_makeExercise(kind, item, shuffled));
    }
    return queue;
  }

  ExerciseKind _pickKind(LearningItem item) {
    if (item.isSentence && item.sourceText.trim().split(RegExp(r'\s+')).length >= 3) {
      final options = [
        ExerciseKind.multipleChoice,
        ExerciseKind.typing,
        ExerciseKind.sentenceBuilder,
      ];
      return options[_random.nextInt(options.length)];
    }
    final options = [ExerciseKind.multipleChoice, ExerciseKind.typing];
    return options[_random.nextInt(options.length)];
  }

  Exercise _makeExercise(
    ExerciseKind kind,
    LearningItem item,
    List<LearningItem> pool,
  ) {
    switch (kind) {
      case ExerciseKind.flashcard:
        return Exercise(kind: kind, item: item);
      case ExerciseKind.multipleChoice:
        return Exercise(
          kind: kind,
          item: item,
          choices: _choices(item, pool),
        );
      case ExerciseKind.typing:
        return Exercise(kind: kind, item: item);
      case ExerciseKind.sentenceBuilder:
        final words = item.sourceText.trim().split(RegExp(r'\s+'));
        final tiles = [...words]..shuffle(_random);
        return Exercise(kind: kind, item: item, shuffledWords: tiles);
    }
  }

  List<String> _choices(LearningItem item, List<LearningItem> pool) {
    final others = pool
        .where((e) => e.id != item.id && e.targetText != item.targetText)
        .map((e) => e.targetText)
        .toSet()
        .toList()
      ..shuffle(_random);
    final picks = others.take(3).toList();
    while (picks.length < 3) {
      picks.add('(no other option)');
    }
    return [...picks, item.targetText]..shuffle(_random);
  }

  /// Normalizes answers: trims, collapses whitespace, case-insensitive.
  static bool checkAnswer(String expected, String given) {
    String norm(String s) =>
        s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    return norm(expected) == norm(given);
  }
}
