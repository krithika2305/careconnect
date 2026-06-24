import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import 'zego_call_service.dart';

class IncomingConsultationCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> consultation;
  final String role;

  const IncomingConsultationCard({
    super.key,
    required this.consultation,
    required this.role,
  });

  @override
  ConsumerState<IncomingConsultationCard> createState() => _IncomingConsultationCardState();
}

class _IncomingConsultationCardState extends ConsumerState<IncomingConsultationCard> {
  String _doctorName = 'Loading...';
  String _patientName = 'Loading...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  @override
  void didUpdateWidget(covariant IncomingConsultationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consultation['id'] != widget.consultation['id']) {
      _loadNames();
    }
  }

  Future<void> _loadNames() async {
    final client = ref.read(supabaseClientProvider);
    final doctorId = widget.consultation['doctor_id'];
    final patientId = widget.consultation['patient_id'];

    try {
      String docName = 'Doctor';
      String patName = 'Patient';

      if (doctorId != null) {
        final doc = await client.from('users').select('name').eq('id', doctorId).maybeSingle();
        if (doc != null) {
          docName = doc['name']?.toString() ?? 'Doctor';
        }
      }

      if (patientId != null) {
        final pat = await client.from('users').select('name').eq('id', patientId).maybeSingle();
        if (pat != null) {
          patName = pat['name']?.toString() ?? 'Patient';
        }
      }

      if (mounted) {
        setState(() {
          _doctorName = docName;
          _patientName = patName;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final client = ref.read(supabaseClientProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final userName = profile?['name'] ?? 'User';
    final userId = client.auth.currentUser?.id ?? '';

    final roomId = widget.consultation['room_id']?.toString() ?? '';
    final consultationId = widget.consultation['id']?.toString() ?? '';

    if (widget.role == 'patient') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: MedicalTheme.primaryTeal.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.video_camera_front_rounded, color: MedicalTheme.primaryTeal, size: 28),
                const SizedBox(width: 10),
                const Text(
                  'Video Consultation',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Dr. $_doctorName is online.',
              style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MedicalTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => ZegoCallService.joinCall(
                  context,
                  client,
                  consultationId: consultationId,
                  roomId: roomId,
                  userId: userId,
                  userName: userName,
                  role: 'patient',
                ),
                icon: const Icon(Icons.video_call_rounded),
                label: const Text('Join Consultation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    } else if (widget.role == 'caregiver') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CareTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: CareTheme.accentPink.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.live_tv_rounded, color: CareTheme.accentPink, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Consultation',
                  style: CareTheme.bodySans.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: CareTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: CareTheme.bodySans.copyWith(fontSize: 15, color: CareTheme.textPrimary),
                children: [
                  const TextSpan(text: 'Patient: '),
                  TextSpan(text: _patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: '\nDoctor: '),
                  TextSpan(text: 'Dr. $_doctorName', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CareTheme.accentPink,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => ZegoCallService.joinCall(
                  context,
                  client,
                  consultationId: consultationId,
                  roomId: roomId,
                  userId: userId,
                  userName: userName,
                  role: 'caregiver',
                ),
                icon: const Icon(Icons.remove_red_eye_outlined),
                label: const Text('Join Call (Observer)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
