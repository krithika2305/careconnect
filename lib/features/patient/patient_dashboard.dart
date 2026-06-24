import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import 'package:go_router/go_router.dart';
import 'cognitive_history_screen.dart';
import '../shared/memory_photos_screen.dart';
import 'patient_daily_routine_section.dart';
import 'patient_mood_logger_section.dart';
import 'patient_appointments_section.dart';
import '../shared/medication_reminder_card.dart';
import '../../services/notification_service.dart';
import '../../core/widgets/notification_bell.dart';
import '../video_call/consultation_service.dart';
import '../video_call/incoming_consultation_card.dart';

class PatientDashboard extends ConsumerStatefulWidget {
  const PatientDashboard({super.key});
  @override
  ConsumerState<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends ConsumerState<PatientDashboard> {
  int _currentIndex = 0;

  bool _isDispatchingSOS = false;
  String _lastStatus = 'Normal Cognitive Activity';

  int _tapCount = 0;
  int _requiredTaps = 5;
  int _secondsElapsed = 0;
  bool _gameStarted = false;
  Timer? _timer;

  Future<void> _sendSosAlert() async {
    if (_isDispatchingSOS) return;
    setState(() => _isDispatchingSOS = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showAccessibilitySnack('Location services are disabled. Please enable GPS.', isError: true);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showAccessibilitySnack('Location permission is needed to send your position.', isError: true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showAccessibilitySnack('Location permissions are permanently denied.', isError: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));
      final client = ref.read(supabaseClientProvider);
      final session = ref.read(authSessionProvider);
      final profile = await ref.read(userProfileProvider.future);
      final name = profile?['name'] ?? 'Unknown Patient';
      await client.from('emergency_alerts').insert({
        'patient_id': session!.user.id,
        'patient_name': name,
        'alert_type': 'SOS – Patient Needs Help',
        'status': 'ACTIVE',
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      // ── Send notifications to all linked caregivers and doctors ──────────
      final mappings = await client
          .from('caregiver_patient_mapping')
          .select('caregiver_id')
          .eq('patient_id', session!.user.id);
      final caregiverIds = mappings.map((m) => m['caregiver_id'] as String).toSet();

      final docMappings = await client
          .from('doctor_patient_mapping')
          .select('doctor_id')
          .eq('patient_id', session.user.id)
          .eq('status', 'accepted');
      final doctorIds = docMappings.map((m) => m['doctor_id'] as String).toSet();

      final allUserIds = {...caregiverIds, ...doctorIds};

      for (final userId in allUserIds) {
        await NotificationService.send(
          userId: userId,
          title: '🚨 SOS Alert',
          body: '$name needs immediate help. Tap to view location.',
          type: 'sos',
          data: {
            'patient_id': session.user.id,
            'location': {'lat': pos.latitude, 'lng': pos.longitude},
          },
        );
      }
      _showAccessibilitySnack('Help is on the way! Your location has been sent.', isError: false);
    } catch (e) {
      _showAccessibilitySnack('Could not send alert. Please call a family member.', isError: true);
    } finally {
      if (mounted) setState(() => _isDispatchingSOS = false);
    }
  }

  void _showAccessibilitySnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: isError ? MedicalTheme.accentCoral : MedicalTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      _secondsElapsed = 0;
      _tapCount = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  void _registerTap() {
    if (!_gameStarted) return;
    setState(() => _tapCount++);
    if (_tapCount >= _requiredTaps) {
      _timer?.cancel();
      _gameStarted = false;
      _recordCognitiveResult();
    }
  }

  Future<void> _recordCognitiveResult() async {
    final client = ref.read(supabaseClientProvider);
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    final status = _secondsElapsed <= 5
        ? 'Normal Cognitive Activity'
        : _secondsElapsed <= 12
            ? 'Slight Concern – Reaction Slow'
            : 'High Risk – Delayed Reaction';
    try {
      await client.from('cognitive_tests').insert({
        'user_id': session.user.id,
        'play_hour': DateTime.now().hour,
        'duration_sec': _secondsElapsed,
        'tap_count': _tapCount,
        'status': status,
      });
      if (mounted) setState(() => _lastStatus = status);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formattedDate() {
    final now = DateTime.now();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[now.weekday - 1]}, ${months[now.month]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final firstName = (profileAsync.value?['name'] as String?)?.split(' ').first ?? 'Friend';
    final patientId = ref.read(authSessionProvider)?.user.id;
    final stageAsync = patientId != null ? ref.watch(latestPatientStageProvider(patientId)) : null;
    final careStage = stageAsync?.valueOrNull?['stage']?.toString();

    final pages = [
      _DashboardContent(
        firstName: firstName,
        patientId: patientId,
        lastStatus: _lastStatus,
        careStage: careStage,
        isDispatchingSOS: _isDispatchingSOS,
        onSosPressed: _sendSosAlert,
        gameStarted: _gameStarted,
        tapCount: _tapCount,
        requiredTaps: _requiredTaps,
        secondsElapsed: _secondsElapsed,
        onStartGame: _startGame,
        onTapGame: _registerTap,
      ),
      patientId != null ? MemoryPhotosScreen(patientId: patientId, isCaregiver: false) : const Center(child: Text('No patient ID')),
      const CognitiveHistoryScreen(),
    ];

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        foregroundColor: CareTheme.textPrimary,
        title: Text('CareConnect', style: CareTheme.bodySans.copyWith(fontSize: 22, fontWeight: FontWeight.bold, color: CareTheme.textPrimary, letterSpacing: -0.3)),
        actions: [
          NotificationBell(),
          IconButton(
            iconSize: 32,
            icon: Icon(Icons.logout_outlined, color: CareTheme.textMuted),
            onPressed: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
              ref.invalidate(authSessionProvider);
              ref.invalidate(userProfileProvider);
              if (mounted) context.go('/welcome');
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: MedicalTheme.primaryTeal,
        unselectedItemColor: Colors.white60,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'Memory Photos'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Activity'),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final String firstName;
  final String? patientId;
  final String lastStatus;
  final String? careStage;
  final bool isDispatchingSOS;
  final VoidCallback onSosPressed;
  final bool gameStarted;
  final int tapCount;
  final int requiredTaps;
  final int secondsElapsed;
  final VoidCallback onStartGame;
  final VoidCallback onTapGame;

  const _DashboardContent({
    required this.firstName,
    required this.patientId,
    required this.lastStatus,
    required this.careStage,
    required this.isDispatchingSOS,
    required this.onSosPressed,
    required this.gameStarted,
    required this.tapCount,
    required this.requiredTaps,
    required this.secondsElapsed,
    required this.onStartGame,
    required this.onTapGame,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hello, $firstName', style: TextStyle(color: CareTheme.textPrimary, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -0.6)),
            const SizedBox(height: 6),
            Text(_formattedDate(), style: TextStyle(color: CareTheme.textMuted, fontSize: 18)),
            const SizedBox(height: 28),
            _SosButton(isLoading: isDispatchingSOS, onPressed: onSosPressed),
            const SizedBox(height: 28),
            if (careStage != null) ...[
              _CareStageCard(stage: careStage!),
              const SizedBox(height: 20),
            ],
            Consumer(
              builder: (context, ref, _) {
                final activeConsultAsync = ref.watch(activeConsultationProvider);
                return activeConsultAsync.when(
                  data: (consultation) {
                    if (consultation != null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: IncomingConsultationCard(
                          consultation: consultation,
                          role: 'patient',
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
            const Text("Today's Reminders", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 12),
            if (patientId != null) _RemindersList(patientId: patientId!),
            const SizedBox(height: 20),
            if (patientId != null) PatientDailyRoutineSection(patientId: patientId!),
            const SizedBox(height: 20),
            if (patientId != null)
              ClipRect(   // ← extra safety to clip any remaining overflow
                child: PatientMoodLoggerSection(patientId: patientId!),
              ),
            const SizedBox(height: 16),
            _CognitiveGameCard(
              gameStarted: gameStarted,
              tapCount: tapCount,
              requiredTaps: requiredTaps,
              secondsElapsed: secondsElapsed,
              onStart: onStartGame,
              onTap: onTapGame,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[now.weekday - 1]}, ${months[now.month]} ${now.day}';
  }
}

// ── Helper widgets (unchanged but moved for clarity) ─────────────────────────

class _SosButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _SosButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: isLoading ? MedicalTheme.accentCoral.withOpacity(0.6) : MedicalTheme.accentCoral,
          borderRadius: BorderRadius.circular(28),
          boxShadow: isLoading ? [] : [BoxShadow(color: MedicalTheme.accentCoral.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: isLoading
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                SizedBox(height: 12),
                Text('Sending your location…', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]))
            : const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.sos_rounded, color: Colors.white, size: 52),
                SizedBox(height: 8),
                Text('NEED HELP? TAP HERE', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                SizedBox(height: 4),
                Text('Sends your location to your caregiver', style: TextStyle(color: Colors.white70, fontSize: 15)),
              ])),
      ),
    );
  }
}

class _CareStageCard extends StatelessWidget {
  final String stage;
  const _CareStageCard({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MedicalTheme.primaryTeal.withOpacity(0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.timeline_rounded, color: MedicalTheme.primaryTeal, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Care stage', style: TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 4),
            Text(stage, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.2)),
          ]),
        ),
      ]),
    );
  }
}

class _CognitiveGameCard extends StatelessWidget {
  final bool gameStarted;
  final int tapCount;
  final int requiredTaps;
  final int secondsElapsed;
  final VoidCallback onStart;
  final VoidCallback onTap;

  const _CognitiveGameCard({
    required this.gameStarted,
    required this.tapCount,
    required this.requiredTaps,
    required this.secondsElapsed,
    required this.onStart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (tapCount / requiredTaps).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.bolt_rounded, color: MedicalTheme.secondaryMint, size: 28),
          SizedBox(width: 10),
          Text('Daily Brain Exercise', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        const Text('Tap the button quickly to test your reaction today.', style: TextStyle(color: Colors.white60, fontSize: 16, height: 1.4)),
        const SizedBox(height: 20),
        if (gameStarted) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statChip('Time', '$secondsElapsed s'),
            _statChip('Taps', '$tapCount / $requiredTaps'),
          ]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 10, color: MedicalTheme.secondaryMint, backgroundColor: Colors.white12),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 80,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: MedicalTheme.secondaryMint, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: onTap,
              child: const Text('TAP!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: 72,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: MedicalTheme.secondaryMint, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: onStart,
              child: const Text('Start Exercise', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _RemindersList extends ConsumerWidget {
  final String patientId;
  const _RemindersList({required this.patientId});

  String _formatTime(String? time) {
    if (time == null) return '';
    final parts = time.split(':');
    if (parts.length < 2) return time;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(scheduledMessagesProvider(patientId));
    return remindersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading reminders: $e', style: const TextStyle(color: Colors.red)),
      data: (reminders) {
        if (reminders.isEmpty) {
          return const Text('No reminders scheduled. Your caregiver will add them.', style: TextStyle(color: Colors.white70));
        }
        return Column(
          children: reminders.map((r) => MedicationReminderCard(
                title: r['title']?.toString() ?? 'Medication',
                time: _formatTime(r['scheduled_time']?.toString()),
                pillImageUrl: r['pill_image_url']?.toString(),
                dosage: r['dosage']?.toString(),
                instructions: r['instructions']?.toString(),
                type: r['type']?.toString(),
                darkStyle: true,
              )).toList(),
        );
      },
    );
  }
}