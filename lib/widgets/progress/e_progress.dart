import 'package:flutter/material.dart';

import '../../core/design/e_design.dart';

/// E progress ring (spec §4, §32): daily-goal completion with an explicit
/// "done / goal" label — never color-only (spec §6).
class EProgressRing extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final int done;
  final int goal;
  final double size;

  const EProgressRing({
    super.key,
    required this.value,
    required this.done,
    required this.goal,
    this.size = 88,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (value.clamp(0.0, 1.0) * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: 9,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text('$done/$goal', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// E linear progress with text label (spec §5).
class ELabeledProgress extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final String label;

  const ELabeledProgress({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0.0, 1.0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: ESpacing.sm),
            Text(
              '$pct%',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(ERadii.sm),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

/// E streak pill (mockup §7: sun-yellow pill with fire icon and
/// explicit "N Day Streak" text — never color-only, spec §6).
class EStreakPill extends StatelessWidget {
  final int days;

  const EStreakPill({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ESpacing.lg,
        vertical: ESpacing.sm,
      ),
      decoration: BoxDecoration(
        color: EColors.sun,
        borderRadius: BorderRadius.circular(ERadii.pill),
        boxShadow: [
          BoxShadow(
            color: EColors.sun.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, color: EColors.ink, size: 20),
          const SizedBox(width: ESpacing.xs),
          Text(
            '$days Day Streak',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: EColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// E status chip (spec §34): review state as text on a tinted pill.
/// Text carries the meaning; color only reinforces it.
class EStatusChip extends StatelessWidget {
  final String status; // new | learning | review | mastered

  const EStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'mastered' => EColors.success,
      'review' => Theme.of(context).colorScheme.primary,
      'learning' => EColors.streak,
      _ => Theme.of(context).colorScheme.outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ERadii.pill),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// E section heading (spec §5): consistent title style for card headers.
class ESectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ESectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
