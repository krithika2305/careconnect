import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme.dart';
import '../../core/widgets/care_ui.dart';
import '../../services/onboarding_service.dart';
import '../../services/providers.dart';


class OnboardingGoalsScreen extends ConsumerStatefulWidget {
  const OnboardingGoalsScreen({super.key});

  @override
  ConsumerState<OnboardingGoalsScreen> createState() =>
      _OnboardingGoalsScreenState();
}

class _OnboardingGoalsScreenState extends ConsumerState<OnboardingGoalsScreen> {
  final _options = <String, bool>{
    'Help them remember medications': false,
    'Keep them hydrated with helpful nudges': false,
    'Track how they are doing to share with their doctor': false,
    'See helpful insights about their daily routines': false,
    'Get alerts if they leave a safe zone': false,
  };

  @override
  Widget build(BuildContext context) {
    return CareOnboardingShell(
      progress: 0.35,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How can we help you support your loved one?',
              textAlign: TextAlign.center,
              style: CareTheme.displaySerif.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 10),
            Text(
              'Choose what to set up now — you can add more anytime.',
              textAlign: TextAlign.center,
              style: CareTheme.bodySans.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: _options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final key = _options.keys.elementAt(index);
                  return CareSelectionTile(
                    label: key,
                    selected: _options[key]!,
                    onTap: () => setState(() => _options[key] = !_options[key]!),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: () => context.push('/onboarding/loved-one'),
            child: const Text('Continue'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text('Back', style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted)),
              ),
              TextButton(
                onPressed: () => context.push('/onboarding/loved-one'),
                child: Text('Skip for Now', style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardingNotificationsScreen extends StatelessWidget {
  const OnboardingNotificationsScreen({super.key});

  Future<void> _enableNotifications(BuildContext context) async {
    await Permission.notification.request();
    if (context.mounted) context.push('/onboarding/complete');
  }

  @override
  Widget build(BuildContext context) {
    return CareOnboardingShell(
      progress: 0.85,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              "Let's Keep You Updated",
              textAlign: TextAlign.center,
              style: CareTheme.displaySerif.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 32),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: CareTheme.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  size: 52, color: CareTheme.accentPink),
            ),
            const SizedBox(height: 32),
            Text(
              'CareConnect can notify you if your loved one misses a reminder, leaves a safe zone, or if something seems unusual.',
              textAlign: TextAlign.center,
              style: CareTheme.bodySans.copyWith(fontSize: 16),
            ),
            const Spacer(),
          ],
        ),
      ),
      bottom: Column(
        children: [
          ElevatedButton(
            onPressed: () => _enableNotifications(context),
            child: const Text('Turn On Notifications'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/onboarding/complete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CareTheme.textSecondary,
              side: BorderSide(color: CareTheme.textMuted.withValues(alpha: 0.4)),
            ),
            child: const Text('Not Now'),
          ),
        ],
      ),
    );
  }
}

class OnboardingCompleteScreen extends ConsumerWidget {
  const OnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CareOnboardingShell(
      progress: 1,
      showBack: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              "You're all set!",
              style: CareTheme.displaySerif.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 12),
            Text(
              "Here's what CareConnect has set up for you:",
              textAlign: TextAlign.center,
              style: CareTheme.bodySans.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 32),
            _SetupCard(icon: Icons.medication_rounded, label: 'Medication reminders'),
            const SizedBox(height: 12),
            _SetupCard(icon: Icons.water_drop_outlined, label: 'Hydration nudges'),
            const SizedBox(height: 20),
            Text(
              'You can add more at any time.',
              style: CareTheme.bodySans.copyWith(fontSize: 14, color: CareTheme.textMuted),
            ),
            const Spacer(),
          ],
        ),
      ),
      bottom: ElevatedButton(
        onPressed: () async {
          await OnboardingService.markComplete();
          ref.invalidate(onboardingCompleteProvider);
          if (context.mounted) context.go('/caregiver');
        },
        child: const Text('Continue to Dashboard'),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SetupCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: CareTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CareTheme.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: CareTheme.textPrimary, size: 22),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: CareTheme.bodySans.copyWith(
              color: CareTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
