import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import '../auth/login_screen.dart';
import 'cognitive_history_screen.dart';

/// Highly accessible patient-facing dashboard.
/// Design principles:
///  • Minimum 20sp body text, 28sp+ for key labels
///  • High-contrast colour pairs (WCAG AA+)
///  • Large, round touch targets (≥ 72×72 logical px)
///  • No small icons or fine details that could confuse
///  • One primary action per screen section
class PatientDashboard extends ConsumerStatefulWidget {
  const PatientDashboard({super.key});

  @override
  ConsumerState<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends ConsumerState<PatientDashboard> {
  bool _isDispatchingSOS = false;
  String _lastStatus = 'Normal Cognitive Activity';

  // ── SOS Emergency Alert ──────────────────────────────────────────────────

  Future<void> _sendSosAlert() async {
    if (_isDispatchingSOS) return;

    setState(() => _isDispatchingSOS = true);

    try {
      // Request permission
      final permStatus = await Permission.location.request();
      if (!permStatus.isGranted) {
        _showAccessibilitySnack(
          'Location permission is needed to send your position.',
          isError: true,
        );
        return;
      }

      // Get GPS
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      // Write alert to Supabase
      final client  = ref.read(supabaseClientProvider);
      final session = ref.read(authSessionProvider);

      final profile = await ref.read(userProfileProvider.future);
      final name    = profile?['name'] ?? 'Unknown Patient';

      await client.from('emergency_alerts').insert({
        'patient_id':    session!.user.id,
        'patient_name':  name,
        'alert_type':    'SOS – Patient Needs Help',
        'status':        'ACTIVE',
        'latitude':      pos.latitude,
        'longitude':     pos.longitude,
      });

      _showAccessibilitySnack('Help is on the way! Your location has been sent.',
          isError: false);
    } catch (e) {
      _showAccessibilitySnack(
          'Could not send alert. Please call a family member.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isDispatchingSOS = false);
    }
  }

  void _showAccessibilitySnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor:
            isError ? MedicalTheme.accentCoral : MedicalTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }

  // ── Cognitive tap game ───────────────────────────────────────────────────

  int _tapCount    = 0;
  int _requiredTaps = 5;
  int _secondsElapsed = 0;
  bool _gameStarted = false;
  Timer? _timer;

  void _startGame() {
    setState(() {
      _gameStarted    = true;
      _secondsElapsed = 0;
      _tapCount       = 0;
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
    final client  = ref.read(supabaseClientProvider);
    final session = ref.read(authSessionProvider);
    if (session == null) return;

    final status = _secondsElapsed <= 5
        ? 'Normal Cognitive Activity'
        : _secondsElapsed <= 12
            ? 'Slight Concern – Reaction Slow'
            : 'High Risk – Delayed Reaction';

    try {
      await client.from('cognitive_tests').insert({
        'user_id':      session.user.id,
        'play_hour':    DateTime.now().hour,
        'duration_sec': _secondsElapsed,
        'tap_count':    _tapCount,
        'status':       status,
      });
      if (mounted) setState(() => _lastStatus = status);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final firstName    = (profileAsync.value?['name'] as String?)
            ?.split(' ')
            .first ??
        'Friend';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark high-contrast background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text(
          'CareConnect',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            iconSize: 32,
            icon: const Icon(Icons.logout_outlined, color: Colors.white70),
            onPressed: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
              ref.invalidate(authSessionProvider);
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Greeting ─────────────────────────────────────────────────
              Text(
                'Hello, $firstName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formattedDate(),
                style: const TextStyle(
                    color: Colors.white60, fontSize: 18),
              ),
              const SizedBox(height: 28),

              // ── SOS Button (primary action) ──────────────────────────────
              _SosButton(
                isLoading: _isDispatchingSOS,
                onPressed: _sendSosAlert,
              ),
              const SizedBox(height: 28),

              // ── Status card ───────────────────────────────────────────────
              _StatusCard(status: _lastStatus),
              const SizedBox(height: 28),

              // ── Cognitive tap game ────────────────────────────────────────
              _CognitiveGameCard(
                gameStarted: _gameStarted,
                tapCount: _tapCount,
                requiredTaps: _requiredTaps,
                secondsElapsed: _secondsElapsed,
                onStart: _startGame,
                onTap: _registerTap,
              ),
              const SizedBox(height: 28),

              // ── View history ──────────────────────────────────────────────
              _AccessibleActionTile(
                icon: Icons.history_rounded,
                color: MedicalTheme.secondaryMint,
                label: 'View My Activity History',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CognitiveHistoryScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _formattedDate() {
    final now  = DateTime.now();
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month]} ${now.day}';
  }
}

// ── Reusable accessible widgets ──────────────────────────────────────────────

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
          color: isLoading
              ? MedicalTheme.accentCoral.withOpacity(0.6)
              : MedicalTheme.accentCoral,
          borderRadius: BorderRadius.circular(28),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: MedicalTheme.accentCoral.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                    SizedBox(height: 12),
                    Text('Sending your location…',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sos_rounded, color: Colors.white, size: 52),
                    SizedBox(height: 8),
                    Text(
                      'NEED HELP? TAP HERE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sends your location to your caregiver',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final isNormal = status.contains('Normal');
    final color    = isNormal ? MedicalTheme.accentGreen : MedicalTheme.accentOrange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(
            isNormal ? Icons.check_circle_rounded : Icons.info_rounded,
            color: color,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Latest Result',
                  style: TextStyle(color: Colors.white60, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.2),
              ),
            ],
          ),
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
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.bolt_rounded, color: MedicalTheme.secondaryMint, size: 28),
            SizedBox(width: 10),
            Text(
              'Daily Brain Exercise',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Tap the button quickly to test your reaction today.',
            style: TextStyle(color: Colors.white60, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 20),

          if (gameStarted) ...[
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statChip('Time', '$secondsElapsed s'),
                _statChip('Taps', '$tapCount / $requiredTaps'),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                color: MedicalTheme.secondaryMint,
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MedicalTheme.secondaryMint,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: onTap,
                child: const Text(
                  'TAP!',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 72,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MedicalTheme.secondaryMint,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: onStart,
                child: const Text(
                  'Start Exercise',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white60, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _AccessibleActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _AccessibleActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white38, size: 20),
        ]),
      ),
    );
  }
}
