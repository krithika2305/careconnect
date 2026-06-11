import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../shared/appointment_card.dart';

/// Upcoming doctor visits for the patient dashboard.
class PatientAppointmentsSection extends ConsumerWidget {
  final String patientId;

  const PatientAppointmentsSection({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(patientAppointmentsProvider(patientId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_available_rounded, color: CareTheme.accentPink, size: 26),
            const SizedBox(width: 8),
            Text(
              'Upcoming visits',
              style: TextStyle(
                color: CareTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        appointmentsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(color: CareTheme.accentPink),
            ),
          ),
          error: (e, _) => Text(
            'Could not load visits: $e',
            style: TextStyle(color: CareTheme.error, fontSize: 15),
          ),
          data: (visits) {
            if (visits.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CareTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CareTheme.surfaceLight),
                ),
                child: Text(
                  'No upcoming appointments. Your caregiver will add doctor visits here.',
                  style: TextStyle(color: CareTheme.textMuted, fontSize: 16),
                ),
              );
            }

            return Column(
              children: visits.take(5).map((a) {
                return AppointmentCard(
                  doctorName: a['doctor_name']?.toString() ?? 'Visit',
                  appointmentType: a['appointment_type']?.toString(),
                  location: a['location']?.toString(),
                  appointmentTimeIso: a['appointment_time']?.toString() ?? '',
                  notes: a['notes']?.toString(),
                  compact: visits.length > 2,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
