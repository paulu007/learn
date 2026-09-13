import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/e_design.dart';

/// Text-first feedback banner (spec §6, §49): icon + explicit label, never
/// color-only. [correct] selects the green/red treatment.
class EFeedbackBanner extends StatelessWidget {
  final bool correct;
  final String? detail;

  const EFeedbackBanner({super.key, required this.correct, this.detail});

  @override
  Widget build(BuildContext context) {
    final color = correct ? EColors.success : EColors.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ESpacing.lg,
        vertical: ESpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ERadii.md),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
          const SizedBox(width: ESpacing.md),
          Expanded(
            child: Text(
              detail ??
                  (correct ? EFeedbackText.correct : EFeedbackText.incorrect),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Delightful empty state (spec §5, §50): icon, title, message, and up to
/// two actions. No screen may render blank.
class EEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const EEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ESpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(ERadii.xl),
              ),
              child: Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: ESpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ESpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (primaryLabel != null) ...[
              const SizedBox(height: ESpacing.lg),
              FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: ESpacing.sm),
              OutlinedButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Polished skeleton loader (spec §52): shimmer-free pulsing placeholders
/// that keep layout stable while content loads. Never freeze the UI.
class ESkeletonList extends StatefulWidget {
  final int rows;

  const ESkeletonList({super.key, this.rows = 3});

  @override
  State<ESkeletonList> createState() => _ESkeletonListState();
}

class _ESkeletonListState extends State<ESkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Column(
        children: [
          for (var i = 0; i < widget.rows; i++)
            Container(
              height: 72,
              margin: const EdgeInsets.symmetric(
                horizontal: ESpacing.lg,
                vertical: ESpacing.sm,
              ),
              decoration: BoxDecoration(
                color: base.withValues(alpha: 0.5 + _ctrl.value * 0.5),
                borderRadius: BorderRadius.circular(ERadii.lg),
              ),
            ),
        ],
      ),
    );
  }
}

/// Async wrapper: skeleton while loading, human-readable error (spec §51)
/// with retry, content when ready.
class EAsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget Function(Object error)? onError;
  final VoidCallback? onRetry;

  const EAsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onError,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const ESkeletonList(),
      error: (e, _) =>
          onError?.call(e) ??
          EEmptyState(
            icon: Icons.cloud_off_outlined,
            title: "We couldn't load this",
            message: 'Something went wrong on our side. Your data is safe — please try again.',
            primaryLabel: 'Try Again ↻',
            onPrimary: onRetry,
          ),
      data: builder,
    );
  }
}

/// Confirmation dialog for destructive actions (spec §38): always states
/// what happens, always requires an explicit confirm tap.
Future<bool> eConfirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: EColors.danger)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Copies text and confirms with a snackbar.
Future<void> eCopyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }
}
