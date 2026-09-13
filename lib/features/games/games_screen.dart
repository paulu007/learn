import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';

/// Games hub: pick a lesson (or all lessons), then play timed flashcards,
/// word matching, or quick answer.
class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  String? _lessonId;
  int _duration = 60;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Play with:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _LessonPicker(
                selectedId: _lessonId,
                onPick: (id) => setState(() => _lessonId = id),
              ),
              const SizedBox(height: 8),
              Text('Timed game length: $_duration seconds'),
              Row(
                children: [30, 60, 90]
                    .map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${d}s'),
                          selected: _duration == d,
                          onSelected: (_) => setState(() => _duration = d),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        _gameTile(
          context,
          icon: Icons.timer_outlined,
          title: 'Timed Flashcards',
          subtitle: 'How many can you answer before time runs out?',
          onTap: () => _start(
            context,
            (items) => TimedFlashcardsScreen(
              items: items,
              seconds: _duration,
              lessonId: _lessonId,
            ),
          ),
        ),
        _gameTile(
          context,
          icon: Icons.link_outlined,
          title: 'Word Matching',
          subtitle: 'Match words with their translations.',
          onTap: () => _start(
            context,
            (items) => WordMatchingScreen(items: items, lessonId: _lessonId),
          ),
        ),
        _gameTile(
          context,
          icon: Icons.bolt_outlined,
          title: 'Quick Answer',
          subtitle: 'Pick the right translation, fast.',
          onTap: () => _start(
            context,
            (items) => QuickAnswerScreen(items: items, lessonId: _lessonId),
          ),
        ),
        const _BestScores(),
      ],
    );
  }

  Widget _gameTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SectionCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  Future<void> _start(
    BuildContext context,
    Widget Function(List<LearningItem>) build,
  ) async {
    final repo = ref.read(repositoryProvider);
    List<LearningItem> items;
    if (_lessonId == null) {
      final all = await repo.allLessons();
      items = [];
      for (final (_, lesson) in all.take(5)) {
        items.addAll(await repo.itemsOfLesson(lesson.id));
      }
      items = items.take(30).toList()..shuffle();
    } else {
      items = await repo.itemsOfLesson(_lessonId!);
      items.shuffle();
      items = items.take(30).toList();
    }
    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No items to play with yet — import a lesson first.'),
          ),
        );
      }
      return;
    }
    if (context.mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => build(items)));
    }
  }
}

class _LessonPicker extends ConsumerWidget {
  final String? selectedId;
  final void Function(String? id) onPick;

  const _LessonPicker({required this.selectedId, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider);
    return courses.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const Text('No lessons yet.');
        return FutureBuilder(
          future: ref.read(repositoryProvider).allLessons(),
          builder: (ctx, snap) {
            final all = snap.data ?? [];
            return DropdownButtonFormField<String?>(
              initialValue: selectedId,
              decoration: const InputDecoration(labelText: 'Lesson'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All lessons (mixed)'),
                ),
                for (final (course, lesson) in all)
                  DropdownMenuItem(
                    value: lesson.id,
                    child: Text(
                      '${course.title} · ${lesson.title}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onPick,
            );
          },
        );
      },
    );
  }
}

class _BestScores extends ConsumerWidget {
  const _BestScores();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Best Scores',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final game in ['timed', 'matching', 'quick'])
            FutureBuilder(
              future: ref.read(repositoryProvider).bestScore(game),
              builder: (ctx, snap) => Text(
                '${_gameName(game)}: ${snap.data ?? 0}%',
              ),
            ),
        ],
      ),
    );
  }

  String _gameName(String type) => switch (type) {
    'timed' => 'Timed Flashcards',
    'matching' => 'Word Matching',
    _ => 'Quick Answer',
  };
}

Future<void> finishGame(
  WidgetRef ref,
  BuildContext context, {
  required String gameType,
  required String? lessonId,
  required int correct,
  required int wrong,
  required int seconds,
}) async {
  final repo = ref.read(repositoryProvider);
  await repo.saveGameResult(
    gameType: gameType,
    lessonId: lessonId,
    correct: correct,
    wrong: wrong,
    durationSeconds: seconds,
  );
  final best = await repo.bestScore(gameType, lessonId: lessonId);
  final total = correct + wrong;
  final score = total == 0 ? 0 : ((correct / total) * 100).round();
  refreshAfterStudy(ref);
  if (context.mounted) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameResultScreen(
          correct: correct,
          wrong: wrong,
          score: score,
          best: best,
        ),
      ),
    );
  }
}

class GameResultScreen extends StatelessWidget {
  final int correct;
  final int wrong;
  final int score;
  final int best;

  const GameResultScreen({
    super.key,
    required this.correct,
    required this.wrong,
    required this.score,
    required this.best,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Complete')),
      body: Center(
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
              FeedbackBanner(correct: score >= 60),
              const SizedBox(height: 12),
              Text(
                'Correct: $correct\nWrong: $wrong\nScore: $score%\nBest Score: $best%',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Back to Games',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Timed flashcards ----------

class TimedFlashcardsScreen extends ConsumerStatefulWidget {
  final List<LearningItem> items;
  final int seconds;
  final String? lessonId;

  const TimedFlashcardsScreen({
    super.key,
    required this.items,
    required this.seconds,
    this.lessonId,
  });

  @override
  ConsumerState<TimedFlashcardsScreen> createState() =>
      _TimedFlashcardsScreenState();
}

class _TimedFlashcardsScreenState
    extends ConsumerState<TimedFlashcardsScreen> {
  late List<LearningItem> _items;
  int _index = 0;
  int _correct = 0;
  int _wrong = 0;
  bool _revealed = false;
  int _left = 0;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _items = [...widget.items]..shuffle();
    _left = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        _finish();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    await finishGame(
      ref,
      context,
      gameType: 'timed',
      lessonId: widget.lessonId,
      correct: _correct,
      wrong: _wrong,
      seconds: widget.seconds - _left,
    );
  }

  String get _clock {
    final m = (_left ~/ 60).toString().padLeft(2, '0');
    final s = (_left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _items.length) {
      // Ran out of cards: reshuffle and keep going until time ends.
      _items.shuffle();
      _index = 0;
    }
    final item = _items[_index];
    return Scaffold(
      appBar: AppBar(title: Text('Time: $_clock')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text(
                  item.sourceText,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _revealed ? item.targetText : 'Tap I Know / Again after recalling',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (!_revealed)
            PrimaryButton(
              label: 'Reveal',
              onPressed: () => setState(() => _revealed = true),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _wrong++;
                      _index++;
                      _revealed = false;
                    }),
                    child: const Text('AGAIN'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => setState(() {
                      _correct++;
                      _index++;
                      _revealed = false;
                    }),
                    child: const Text('I KNOW'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------- Word matching ----------

class WordMatchingScreen extends ConsumerStatefulWidget {
  final List<LearningItem> items;
  final String? lessonId;

  const WordMatchingScreen({super.key, required this.items, this.lessonId});

  @override
  ConsumerState<WordMatchingScreen> createState() =>
      _WordMatchingScreenState();
}

class _WordMatchingScreenState extends ConsumerState<WordMatchingScreen> {
  late List<LearningItem> _round;
  String? _pickedSource;
  final Set<String> _matched = {};
  int _correct = 0;
  int _wrong = 0;
  final _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _round = widget.items.take(6).toList()..shuffle();
    _stopwatch.start();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _maybeFinish() async {
    if (_matched.length == _round.length) {
      _stopwatch.stop();
      await finishGame(
        ref,
        context,
        gameType: 'matching',
        lessonId: widget.lessonId,
        correct: _correct,
        wrong: _wrong,
        seconds: _stopwatch.elapsed.inSeconds,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = [..._round]..shuffle(Random(_round.length));
    return Scaffold(
      appBar: AppBar(title: const Text('Word Matching')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tap a word, then its translation:'),
          const SizedBox(height: 12),
          for (final item in _round)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: _matched.contains(item.id)
                      ? OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.green,
                            width: 2,
                          ),
                        )
                      : _pickedSource == item.id
                      ? OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary,
                            width: 2,
                          ),
                        )
                      : null,
                  onPressed: _matched.contains(item.id)
                      ? null
                      : () => setState(() => _pickedSource = item.id),
                  child: Text(item.sourceText),
                ),
              ),
            ),
          const Divider(height: 24),
          for (final item in targets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: _matched.contains(item.id)
                      ? OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.green,
                            width: 2,
                          ),
                        )
                      : null,
                  onPressed: _matched.contains(item.id) || _pickedSource == null
                      ? null
                      : () {
                          final ok = _pickedSource == item.id;
                          setState(() {
                            if (ok) {
                              _matched.add(item.id);
                              _correct++;
                            } else {
                              _wrong++;
                            }
                            _pickedSource = null;
                          });
                          _maybeFinish();
                        },
                  child: Text(item.targetText),
                ),
              ),
            ),
          Text('Matched: ${_matched.length} / ${_round.length}'),
        ],
      ),
    );
  }
}

// ---------- Quick answer ----------

class QuickAnswerScreen extends ConsumerStatefulWidget {
  final List<LearningItem> items;
  final String? lessonId;

  const QuickAnswerScreen({super.key, required this.items, this.lessonId});

  @override
  ConsumerState<QuickAnswerScreen> createState() => _QuickAnswerScreenState();
}

class _QuickAnswerScreenState extends ConsumerState<QuickAnswerScreen> {
  int _index = 0;
  int _correct = 0;
  int _wrong = 0;
  String? _picked;
  final _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  List<String> _choices(LearningItem item) {
    final others = widget.items
        .where((e) => e.id != item.id)
        .map((e) => e.targetText)
        .toSet()
        .toList()
      ..shuffle();
    return [...others.take(3), item.targetText]..shuffle();
  }

  Future<void> _next() async {
    if (_index + 1 >= widget.items.length || _index + 1 >= 10) {
      _stopwatch.stop();
      await finishGame(
        ref,
        context,
        gameType: 'quick',
        lessonId: widget.lessonId,
        correct: _correct,
        wrong: _wrong,
        seconds: _stopwatch.elapsed.inSeconds,
      );
    } else {
      setState(() {
        _index++;
        _picked = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index % widget.items.length];
    final choices = _choices(item);
    return Scaffold(
      appBar: AppBar(title: Text('Question ${_index + 1}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Text(
              'What is: ${item.sourceText}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_picked != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FeedbackBanner(correct: _picked == item.targetText),
            ),
          for (final c in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _picked == null
                      ? () => setState(() {
                          _picked = c;
                          if (c == item.targetText) {
                            _correct++;
                          } else {
                            _wrong++;
                          }
                        })
                      : null,
                  child: Text(c),
                ),
              ),
            ),
          if (_picked != null)
            PrimaryButton(label: 'Next', onPressed: _next),
        ],
      ),
    );
  }
}
