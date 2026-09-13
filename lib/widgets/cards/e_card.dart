import 'package:flutter/material.dart';

import '../../core/design/e_design.dart';

/// E hero card (mockup: white card, radius 20, soft shadow, generous
/// 20px padding). Use for streak/progress/continue — the few cards that
/// deserve visual weight. Everything else uses [ESectionCard].
class EHeroCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const EHeroCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.all(ESpacing.xl),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(ERadii.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return _tap(card, onTap!);
  }
}

/// E dark card (mockup: deep-navy card with white text, e.g. the streak
/// banner and the Continue Learning card). Title/body styles adapt; pass
/// explicit white styles via [child] as needed.
class EDarkCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const EDarkCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(ESpacing.xl),
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: EColors.ink,
        borderRadius: BorderRadius.circular(ERadii.xl),
        boxShadow: [
          BoxShadow(
            color: EColors.ink.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return _tap(card, onTap!);
  }
}

/// E section card (spec §5): the default rounded container for content
/// blocks across all screens.
class ESectionCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const ESectionCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(ESpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return _tap(card, onTap!);
  }
}

/// E practice tile (spec §8, §56): large game/quick-action card with icon,
/// title, and subtitle. Always pairs icon with text (spec §6).
class ETile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const ETile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ESectionCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: (iconColor ?? scheme.primary).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(ERadii.lg),
            ),
            child: Icon(icon, color: iconColor ?? scheme.primary, size: 28),
          ),
          const SizedBox(width: ESpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// E review row (mockup "Review" list): white card with a green check
/// icon, word, translation, and a trailing status dot.
class EReviewRow extends StatelessWidget {
  final String word;
  final String translation;
  final bool done;

  const EReviewRow({
    super.key,
    required this.word,
    required this.translation,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(
        horizontal: ESpacing.lg,
        vertical: ESpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(ERadii.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: done
                  ? EColors.leaf.withValues(alpha: 0.15)
                  : scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.check : Icons.refresh,
              size: 20,
              color: done ? EColors.leaf : scheme.primary,
            ),
          ),
          const SizedBox(width: ESpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  translation,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? EColors.leaf : EColors.sun,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _tap(Widget child, VoidCallback onTap) {
  return InkWell(
    borderRadius: BorderRadius.circular(ERadii.xl),
    onTap: onTap,
    child: child,
  );
}
