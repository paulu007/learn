import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';

/// Beautiful learning calendar: studied days, streak, goals, missed days.
/// Tapping a day shows its activity detail.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
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
    final days = ref.watch(activityMonthProvider(_month));
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        SectionCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${_monthName(_month.month)} ${_month.year}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _weekHeader(context),
              AsyncView<List<DailyActivity>>(
                value: days,
                builder: (list) => _grid(context, list),
              ),
              const SizedBox(height: 8),
              _legend(context),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
          bg = Colors.green.withValues(alpha: 0.85);
          fg = Colors.white;
        } else {
          bg = Colors.green.withValues(alpha: 0.3);
        }
      } else if (isFuture || isToday && (act == null || act.activities == 0)) {
        bg = Colors.transparent;
      } else {
        // Past day with no activity: missed.
        bg = Colors.red.withValues(alpha: 0.15);
      }
      if (isToday) label = '$d•';
      cells.add(
        GestureDetector(
          onTap: act == null
              ? null
              : () => setState(() => _selected = act),
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
      final slice = cells.sublist(
        i,
        (i + 7).clamp(0, cells.length),
      );
      while (slice.length < 7) {
        slice.add(const SizedBox(height: 44));
      }
      rows.add(Row(children: [for (final c in slice) Expanded(child: c)]));
    }
    return Column(children: rows);
  }

  Widget _legend(BuildContext context) {
    return const Wrap(
      spacing: 16,
      children: [
        _LegendDot(color: Colors.green, label: 'Goal done'),
        _LegendDot(
          color: Color(0xFF9ACD9A),
          label: 'Studied',
        ),
        _LegendDot(color: Color(0xFFF2B8B8), label: 'Missed'),
      ],
    );
  }

  Widget _dayDetail(BuildContext context, DailyActivity a) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a.day,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text('Activities: ${a.activities}'),
          Text('Words learned: ${a.wordsLearned}'),
          Text('Sentences learned: ${a.sentencesLearned}'),
          Text('Games played: ${a.gamesPlayed}'),
          Text('Study time: ${(a.studySeconds / 60).round()} min'),
          Text(
            a.goalCompleted ? 'Completed — goal reached' : 'Not completed',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: a.goalCompleted ? Colors.green : Colors.red,
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
