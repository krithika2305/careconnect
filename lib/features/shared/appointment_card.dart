import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'appointment_utils.dart';

class AppointmentCard extends StatelessWidget {
  final String doctorName;
  final String? appointmentType;
  final String? location;
  final String appointmentTimeIso;
  final String? notes;
  final VoidCallback? onDelete;
  final bool compact;

  const AppointmentCard({
    super.key,
    required this.doctorName,
    this.appointmentType,
    this.location,
    required this.appointmentTimeIso,
    this.notes,
    this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final upcoming = AppointmentUtils.isUpcoming(appointmentTimeIso);
    final daysLabel = AppointmentUtils.daysUntilLabel(appointmentTimeIso);
    final typeLabel = AppointmentUtils.typeLabel(appointmentType);

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 8 : 12),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: CareTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: upcoming
              ? CareTheme.accentPink.withValues(alpha: 0.35)
              : CareTheme.surfaceLight,
        ),
        boxShadow: [
          BoxShadow(
            color: CareTheme.textPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CareTheme.accentPink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              AppointmentUtils.typeIcon(appointmentType),
              color: CareTheme.accentPink,
              size: compact ? 22 : 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doctorName,
                        style: TextStyle(
                          color: CareTheme.textPrimary,
                          fontSize: compact ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (upcoming && daysLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: CareTheme.accentPeach.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          daysLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: CareTheme.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  typeLabel,
                  style: TextStyle(
                    color: CareTheme.accentPink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppointmentUtils.formatDateTime(appointmentTimeIso),
                  style: TextStyle(color: CareTheme.textMuted, fontSize: 13),
                ),
                if (location != null && location!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 14, color: CareTheme.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location!,
                          style: TextStyle(color: CareTheme.textMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!compact && notes != null && notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    notes!,
                    style: TextStyle(color: CareTheme.textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: CareTheme.error, size: compact ? 20 : 24),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
