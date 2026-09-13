import 'package:flutter/material.dart';

import '../../core/design/e_design.dart';

/// E hero card (spec §4, §5): soft background, generous radius, subtle
/// shadow. Use for streak, daily goal, continue-learning — the few cards
/// that deserve visual weight. Everything else uses [ESectionCard].
class EHeroCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final List<Color>? gradient;
  final EdgeInsetsGeometry padding;

  const EHeroCard({
    super.key,
    required this.child,
    this.onTap,
    this.gradient,
    this.padding = const EdgeInsets.all(ESpacing.xxl),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors =
        gradient ?? [scheme.primaryContainer, scheme.secondaryContainer];
    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ERadii.xl),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
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

Widget _tap(Widget child, VoidCallback onTap) {
  return InkWell(
    borderRadius: BorderRadius.circular(ERadii.xl),
    onTap: onTap,
    child: child,
  );
}
