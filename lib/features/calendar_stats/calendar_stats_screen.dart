import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/design/e_design.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';

/// Calendar + Statistics (spec §44, §45): tabbed detail screens linked
/// from Progress so the five-tab bar keeps the spec's §7 structure.
class CalendarStatsScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const CalendarStatsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<CalendarStatsScreen> createState() =>
      _CalendarStatsScreenState();
}

class _CalendarStatsScreenState extends ConsumerState<CalendarStatsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DailyActivity? _selected;

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calendar & Statistics'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Calendar', icon: Icon(Icons.calendar_month_outlined)),
              Tab(text: 'Statistics', icon: Icon(Icons.bar_chart_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [_calendarTab(context), _statisticsTab(context)],
        ),
      ),
    );
  }

  // ---------------- Calendar (spec §44) ----------------

  Widget _calendarTab(BuildContext context) {
    final days = ref.watch(activityMonthProvider(_month));
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        ESectionCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                  ),
                  Text(
                    '${_monthName(_month.month)} ${_month.year}',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _weekHeader(context),
              EAsyncView<List<DailyActivity>>(
                value: days,
                builder: (list) => _grid(context, list),
              ),
              const SizedBox(height: 8),
              _legend(),
            ],
          ),
        ),
        if (_selected != null) _dayDetail(context, _selected!),
      ],
    );
  }

  Widget _weekHeader(BuildContext context) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: [
        for (final n in names)
          Expanded(
            child: Center(
              child: Text(
                n,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(BuildContext context, List<DailyActivity> list) {
    final byDay = {for (final a in list) a.day: a};
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = (first.weekday - 1) % 7; // Monday start
    final scheme = Theme.of(context).colorScheme;
    final today = dayKey();
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox(height: 44));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final key = dayKey(date);
      final act = byDay[key];
      final isToday = key == today;
      final isFuture = date.isAfter(DateTime.now()) && !isToday;
      Color bg;
      Color fg = scheme.onSurface;
      String label = '$d';
      if (act != null && act.activities > 0) {
        if (act.goalCompleted) {
          bg = EColors.success.withValues(alpha: 0.85);
          fg = Colors.white;
        } else {
          bg = EColors.success.withValues(alpha: 0.3);
        }
      } else if (isFuture || isToday && (act == null || act.activities == 0)) {
        bg = Colors.transparent;
      } else {
        // Past day with no activity: missed.
        bg = EColors.danger.withValues(alpha: 0.15);
      }
      if (isToday) label = '$d•';
      cells.add(
        GestureDetector(
          onTap: act == null ? null : () => setState(() => _selected = act),
          child: Container(
            height: 44,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: isToday
                  ? Border.all(color: scheme.primary, width: 2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }
    // Chunk into week rows.
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final slice = cells.sublist(i, (i + 7).clamp(0, cells.length));
      while (slice.length < 7) {
        slice.add(const SizedBox(height: 44));
      }
      rows.add(Row(children: [for (final c in slice) Expanded(child: c)]));
    }
    return Column(children: rows);
  }

  Widget _legend() {
    return const Wrap(
      spacing: 16,
      children: [
        _LegendDot(color: EColors.success, label: 'Goal done ✓'),
        _LegendDot(color: Color(0xFF9ACD9A), label: 'Studied'),
        _LegendDot(color: Color(0xFFF2B8B8), label: 'Missed ✕'),
      ],
    );
  }

  Widget _dayDetail(BuildContext context, DailyActivity a) {
    return ESectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a.day,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('Activities: ${a.activities}'),
          Text('Words learned: ${a.wordsLearned}'),
          Text('Sentences learned: ${a.sentencesLearned}'),
          Text('Games played: ${a.gamesPlayed}'),
          Text('Study time: ${(a.studySeconds / 60).round()} min'),
          Text(
            a.goalCompleted ? 'Completed ✓ — goal reached' : 'Not completed ✕',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: a.goalCompleted ? EColors.success : EColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m - 1];

  // ---------------- Statistics (spec §45) ----------------

  Widget _statisticsTab(BuildContext context) {
    final totals = ref.watch(totalsProvider);
    return EAsyncView<Map<String, int>>(
      value: totals,
      builder: (t) {
        final correct = t['correct'] ?? 0;
        final wrong = t['wrong'] ?? 0;
        final attempts = correct + wrong;
        final accuracy = attempts == 0
            ? 0
            : ((correct / attempts) * 100).round();
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            ESectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ESectionTitle(title: 'This week'),
                  const SizedBox(height: ESpacing.sm),
                  _weekBars(context),
                ],
              ),
            ),
            ESectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ESectionTitle(title: 'Accuracy'),
                  const SizedBox(height: ESpacing.sm),
                  ELabeledProgress(
                    value: attempts == 0 ? 0 : correct / attempts,
                    label: '$accuracy% correct ($correct/$attempts)',
                  ),
                ],
              ),
            ),
            ESectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ESectionTitle(title: 'Game performance'),
                  const SizedBox(height: ESpacing.sm),
                  for (final game in ['timed', 'matching', 'quick'])
                    FutureBuilder(
                      future: ref.read(repositoryProvider).bestScore(game),
                      builder: (ctx, snap) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${_gameName(game)}: ${snap.data ?? 0}% best',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ESectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ESectionTitle(title: 'Personal records'),
                  const SizedBox(height: ESpacing.sm),
                  _records(context, ref),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _weekBars(BuildContext context) {
    final now = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
    return FutureBuilder(
      future: ref
          .read(repositoryProvider)
          .activityRange(dayKey(days.first), dayKey(days.last)),
      builder: (ctx, snap) {
        final byDay = {for (final a in snap.data ?? []) a.day: a};
        final maxActs = [
          for (final d in days) byDay[dayKey(d)]?.activities ?? 0,
        ].fold<int>(1, (a, b) => a > b ? a : b);
        const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 80,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 20,
                        height:
                            8.0 +
                            72.0 *
                                ((byDay[dayKey(days[i])]?.activities ?? 0)
                                        .toDouble() /
                                    maxActs.toDouble()),
                        decoration: BoxDecoration(
                          color:
                              (byDay[dayKey(days[i])]?.goalCompleted ?? false)
                              ? EColors.success
                              : Theme.of(context).colorScheme.primary
                                    .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      names[(days[i].weekday - 1) % 7],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _records(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: Future.wait([
        ref.read(repositoryProvider).totalStudySeconds(),
        ref.read(repositoryProvider).streak(),
        ref.read(repositoryProvider).totals(),
      ]),
      builder: (ctx, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final secs = snap.data![0] as int;
        final streak = snap.data![1] as StreakInfo;
        final totals = snap.data![2] as Map<String, int>;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total study time: ${(secs / 60).round()} min'),
            Text('Longest streak: ${streak.longest} days'),
            Text('Items learned: ${totals['items'] ?? 0}'),
            Text('Mastered: ${totals['mastered'] ?? 0}'),
          ],
        );
      },
    );
  }

  String _gameName(String type) => switch (type) {
    'timed' => 'Timed Flashcards',
    'matching' => 'Word Matching',
    _ => 'Quick Answer',
  };
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
