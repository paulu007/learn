import 'package:flutter/material.dart';

import 'buttons/e_buttons.dart';
import 'cards/e_card.dart';
import 'common/e_feedback.dart';
import 'progress/e_progress.dart';

export 'buttons/e_buttons.dart';
export 'cards/e_card.dart';
export 'common/e_feedback.dart';
export 'progress/e_progress.dart';

// Compatibility shim (spec Stage 1): the pre-redesign widget names, now
// backed by the E design system. Existing screens keep compiling unchanged.
// New code should import the e_* libraries directly.

/// Rounded content card → [ESectionCard].
class SectionCard extends ESectionCard {
  const SectionCard({
    super.key,
    required super.child,
    super.onTap,
    super.padding,
  });
}

/// Big primary action button → [EPrimaryButton].
class PrimaryButton extends EPrimaryButton {
  const PrimaryButton({
    super.key,
    required super.label,
    super.onPressed,
    super.icon,
  });
}

/// Text-first feedback banner → [EFeedbackBanner].
class FeedbackBanner extends EFeedbackBanner {
  const FeedbackBanner({super.key, required super.correct, super.detail});
}

/// Empty state with optional action → [EEmptyState].
class EmptyState extends EEmptyState {
  const EmptyState({
    super.key,
    required super.icon,
    required super.title,
    required super.message,
    String? actionLabel,
    VoidCallback? onAction,
  }) : super(primaryLabel: actionLabel, onPrimary: onAction);
}

/// Async loading/error/content wrapper → [EAsyncView].
class AsyncView<T> extends EAsyncView<T> {
  const AsyncView({
    super.key,
    required super.value,
    required super.builder,
    super.onError,
    super.onRetry,
  });
}

/// Linear progress with text label → [ELabeledProgress].
class LabeledProgress extends ELabeledProgress {
  const LabeledProgress({
    super.key,
    required super.value,
    required super.label,
  });
}

/// Confirmation dialog for destructive actions → [eConfirmAction].
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = true,
}) => eConfirmAction(
  context,
  title: title,
  message: message,
  confirmLabel: confirmLabel,
  danger: danger,
);

/// Copies text and shows a snackbar → [eCopyText].
Future<void> copyText(BuildContext context, String text) =>
    eCopyText(context, text);
