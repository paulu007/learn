import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/custom_keyboard.dart';
import 'learning_service.dart';

/// Runs a mixed exercise queue for one lesson: flashcards, multiple
/// choice, typing (with the in-app keyboard), and sentence builder.
class LessonSessionScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const LessonSessionScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonSessionScreen> createState() =>
      _LessonSessionScreenState();
}

class _LessonSessionScreenState extends ConsumerState<LessonSessionScreen> {
  List<Exercise>? _queue;
  int _index = 0;
  int _correct = 0;
  int _wrong = 0;
  bool _usedHint = false;
  final _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repositoryProvider);
    final items = await repo.dueItems(widget.lessonId, limit: 50);
    final pool = items.isEmpty
        ? await repo.itemsOfLesson(widget.lessonId)
        : items;
    final progress = await repo.progressForItems(
      pool.map((e) => e.id).toList(),
    );
    final queue = LearningService().buildQueue(
      pool.take(20).toList(),
      progress,
    );
    setState(() => _queue = queue);
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _answerGrade(
    LearningItem item,
    int rating, {
    bool correct = true,
  }) async {
    await ref
        .read(repositoryProvider)
        .rateItem(item, rating, useHint: _usedHint);
    setState(() {
      if (correct) {
        _correct++;
      } else {
        _wrong++;
      }
      _usedHint = false;
      _index++;
    });
    refreshAfterStudy(ref);
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning'),
        actions: [
          if (queue != null && queue.isNotEmpty && _index < queue.length)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_index + 1} / ${queue.length}'),
              ),
            ),
        ],
      ),
      body: Builder(
        builder: (ctx) {
          if (queue == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (queue.isEmpty) {
            return const EmptyState(
              icon: Icons.celebration_outlined,
              title: 'Nothing due right now',
              message:
                  'All items in this lesson are reviewed. Come back later!',
            );
          }
          if (_index >= queue.length) {
            return _summary(context);
          }
          final ex = queue[_index];
          return switch (ex.kind) {
            ExerciseKind.flashcard => _FlashcardView(
              item: ex.item,
              onGrade: (r) => _answerGrade(ex.item, r, correct: r >= 2),
              onHint: () => setState(() => _usedHint = true),
            ),
            ExerciseKind.multipleChoice => _MultipleChoiceView(
              exercise: ex,
              onAnswer: (ok) => _answerGrade(ex.item, ok ? 2 : 0, correct: ok),
              onHint: () => setState(() => _usedHint = true),
            ),
            ExerciseKind.typing => _TypingView(
              item: ex.item,
              onAnswer: (ok) => _answerGrade(ex.item, ok ? 3 : 0, correct: ok),
              onHint: () => setState(() => _usedHint = true),
            ),
            ExerciseKind.sentenceBuilder => _SentenceBuilderView(
              exercise: ex,
              onAnswer: (ok) => _answerGrade(ex.item, ok ? 2 : 0, correct: ok),
              onHint: () => setState(() => _usedHint = true),
            ),
          };
        },
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final total = _correct + _wrong;
    final pct = total == 0 ? 0 : ((_correct / total) * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 72,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            Text(
              'Session Complete',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FeedbackBanner(correct: pct >= 60),
            const SizedBox(height: 12),
            Text(
              'Correct: $_correct · Wrong: $_wrong · Score: $pct%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Back to Lesson',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared hint button: 4 levels, marks the answer as hint-assisted.
class HintButton extends StatelessWidget {
  final LearningItem item;
  final VoidCallback onHintUsed;

  const HintButton({super.key, required this.item, required this.onHintUsed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        onHintUsed();
        var level = 1;
        await showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setState) {
              final hint = hintFor(item, level);
              return AlertDialog(
                title: Text(hint.title),
                content: Text(hint.text),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  if (level < 4)
                    FilledButton(
                      onPressed: () => setState(() => level++),
                      child: const Text('Next Hint'),
                    ),
                ],
              );
            },
          ),
        );
      },
      icon: const Icon(Icons.lightbulb_outline),
      label: const Text('Hint'),
    );
  }
}

class _FlashcardView extends StatefulWidget {
  final LearningItem item;
  final ValueChanged<int> onGrade;
  final VoidCallback onHint;

  const _FlashcardView({
    required this.item,
    required this.onGrade,
    required this.onHint,
  });

  @override
  State<_FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<_FlashcardView> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text(
                widget.item.sourceText,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (!_revealed)
                Text(
                  'Tap to reveal',
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else ...[
                Text(
                  widget.item.targetText,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (widget.item.example.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Example: ${widget.item.example}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
          ),
        ),
        if (!_revealed)
          PrimaryButton(
            label: 'Reveal',
            onPressed: () => setState(() => _revealed = true),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onGrade(0),
                  child: const Text('Again'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onGrade(1),
                  child: const Text('Hard'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onGrade(2),
                  child: const Text('Good'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onGrade(3),
                  child: const Text('Easy'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        HintButton(item: widget.item, onHintUsed: widget.onHint),
      ],
    );
  }
}

class _MultipleChoiceView extends StatefulWidget {
  final Exercise exercise;
  final ValueChanged<bool> onAnswer;
  final VoidCallback onHint;

  const _MultipleChoiceView({
    required this.exercise,
    required this.onAnswer,
    required this.onHint,
  });

  @override
  State<_MultipleChoiceView> createState() => _MultipleChoiceViewState();
}

class _MultipleChoiceViewState extends State<_MultipleChoiceView> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final item = widget.exercise.item;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What is the translation of:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                item.sourceText,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        if (_picked != null) ...[
          FeedbackBanner(correct: _picked == item.targetText),
          const SizedBox(height: 8),
        ],
        for (final choice in widget.exercise.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: _picked == null
                    ? null
                    : choice == item.targetText
                    ? OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green, width: 2),
                      )
                    : choice == _picked
                    ? OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 2),
                      )
                    : null,
                onPressed: _picked == null
                    ? () => setState(() => _picked = choice)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(choice),
                ),
              ),
            ),
          ),
        if (_picked != null)
          PrimaryButton(
            label: 'Continue',
            onPressed: () => widget.onAnswer(_picked == item.targetText),
          )
        else
          HintButton(item: item, onHintUsed: widget.onHint),
      ],
    );
  }
}

class _TypingView extends StatefulWidget {
  final LearningItem item;
  final ValueChanged<bool> onAnswer;
  final VoidCallback onHint;

  const _TypingView({
    required this.item,
    required this.onAnswer,
    required this.onHint,
  });

  @override
  State<_TypingView> createState() => _TypingViewState();
}

class _TypingViewState extends State<_TypingView> {
  String _typed = '';
  bool? _result;

  // The field is read-only: only the in-app keyboard writes to it, so the
  // Android system keyboard never appears.
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Translate:', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                widget.item.targetText,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('Type the word in the source language:'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _typed.isEmpty ? ' ' : _typed,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        if (_result != null) ...[
          FeedbackBanner(
            correct: _result!,
            detail: _result!
                ? 'Correct — well done!'
                : 'Incorrect — the answer is "${widget.item.sourceText}".',
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Continue',
            onPressed: () => widget.onAnswer(_result!),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _typed.isEmpty
                      ? null
                      : () => setState(() {
                          _typed = _typed.isEmpty
                              ? ''
                              : _typed.substring(0, _typed.length - 1);
                        }),
                  child: const Text('Delete'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _typed.trim().isEmpty
                      ? null
                      : () => setState(() {
                          _result = LearningService.checkAnswer(
                            widget.item.sourceText,
                            _typed,
                          );
                        }),
                  child: const Text('Check'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HintButton(item: widget.item, onHintUsed: widget.onHint),
        ],
        const SizedBox(height: 12),
        CustomKeyboard(
          languageHint: 'English',
          onKey: (k) => setState(() => _typed += k.toLowerCase()),
          onBackspace: () => setState(() {
            if (_typed.isNotEmpty) {
              _typed = _typed.substring(0, _typed.length - 1);
            }
          }),
          onSpace: () => setState(() => _typed += ' '),
        ),
      ],
    );
  }
}

class _SentenceBuilderView extends StatefulWidget {
  final Exercise exercise;
  final ValueChanged<bool> onAnswer;
  final VoidCallback onHint;

  const _SentenceBuilderView({
    required this.exercise,
    required this.onAnswer,
    required this.onHint,
  });

  @override
  State<_SentenceBuilderView> createState() => _SentenceBuilderViewState();
}

class _SentenceBuilderViewState extends State<_SentenceBuilderView> {
  final List<String> _picked = [];
  bool? _result;

  @override
  Widget build(BuildContext context) {
    final item = widget.exercise.item;
    final remaining = widget.exercise.shuffledWords
        .asMap()
        .entries
        .where((e) => !_picked.contains('${e.key}:${e.value}'))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Build the sentence:'),
              const SizedBox(height: 8),
              Text(
                item.targetText,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _picked)
                    Chip(
                      label: Text(p.split(':').sublist(1).join(':')),
                      onDeleted: _result == null
                          ? () => setState(() => _picked.remove(p))
                          : null,
                    ),
                  if (_picked.isEmpty) const Text('Tap the words in order…'),
                ],
              ),
            ],
          ),
        ),
        if (_result != null) ...[
          FeedbackBanner(
            correct: _result!,
            detail: _result!
                ? 'Correct — well done!'
                : 'Incorrect — try again next time.',
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Continue',
            onPressed: () => widget.onAnswer(_result!),
          ),
        ] else ...[
          const Text('Available words:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in remaining)
                ActionChip(
                  label: Text(e.value),
                  onPressed: () =>
                      setState(() => _picked.add('${e.key}:${e.value}')),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _picked.isEmpty
                      ? null
                      : () => setState(() => _picked.clear()),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _picked.isEmpty
                      ? null
                      : () {
                          final built = _picked
                              .map((p) => p.split(':').sublist(1).join(':'))
                              .join(' ');
                          setState(() {
                            _result = LearningService.checkAnswer(
                              item.sourceText,
                              built,
                            );
                          });
                        },
                  child: const Text('Check'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HintButton(item: item, onHintUsed: widget.onHint),
        ],
      ],
    );
  }
}
