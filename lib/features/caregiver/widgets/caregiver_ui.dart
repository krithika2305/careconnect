import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class CaregiverDarkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const CaregiverDarkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: CareTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CareTheme.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: card,
      ),
    );
  }
}

class CaregiverSectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CaregiverSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: CareTheme.bodySans.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: CareTheme.textPrimary,
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: CareTheme.bodySans.copyWith(
                color: CareTheme.accentPink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

class CaregiverMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;
  final int badgeCount;
  final VoidCallback? onTap;
  final bool locked;

  const CaregiverMetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    this.badgeCount = 0,
    this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: CaregiverDarkCard(
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CareTheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CareTheme.bodySans.copyWith(fontSize: 12, color: CareTheme.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CareTheme.bodySans.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: badgeCount > 0 ? CareTheme.error : CareTheme.textPrimary,
            ),
          ),
          if (locked) ...[
            const SizedBox(height: 6),
            Text(
              'Tap to link loved one',
              style: CareTheme.bodySans.copyWith(
                fontSize: 10,
                color: CareTheme.accentPink,
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class CaregiverLinkBanner extends StatelessWidget {
  final VoidCallback onLink;

  const CaregiverLinkBanner({super.key, required this.onLink});

  @override
  Widget build(BuildContext context) {
    return CaregiverDarkCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: CareTheme.accentPink.withValues(alpha: 0.9)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connect your loved one',
                  style: CareTheme.displaySerif.copyWith(fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Send an invite by email to link their account and unlock reminders, alerts, and tracking.',
            style: CareTheme.bodySans.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onLink,
              child: const Text('Add loved one'),
            ),
          ),
        ],
      ),
    );
  }
}
