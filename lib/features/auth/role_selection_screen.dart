import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SystemChrome.setSystemUIOverlayStyle(CareTheme.darkOverlay);
    final client = ref.watch(supabaseClientProvider);
    ref.watch(authStateProvider);
    final isLoggedIn = client.auth.currentSession != null;

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else if (isLoggedIn) {
              _signOut(ref, context);
            } else {
              context.go('/welcome');
            }
          },
        ),
        title: Text(
          isLoggedIn ? 'Complete your profile' : 'Join CareConnect',
          style: CareTheme.bodySans.copyWith(color: CareTheme.textPrimary),
        ),
        actions: [
          if (isLoggedIn)
            TextButton(
              onPressed: () => _signOut(ref, context),
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                "How will you use CareConnect?",
                style: CareTheme.displaySerif.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                isLoggedIn
                    ? 'Your account exists but needs a role. Pick one to continue.'
                    : "Choose the experience that best fits your needs.",
                style: CareTheme.bodySans.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  children: [
                    _RoleTile(
                      icon: Icons.favorite_rounded,
                      title: 'Care Partner',
                      subtitle: 'Support a loved one with reminders, safety alerts, and cognitive tracking.',
                      onTap: () => context.go('/register?role=caregiver'),
                    ),
                    const SizedBox(height: 12),
                    _RoleTile(
                      icon: Icons.person_rounded,
                      title: 'Person Receiving Care',
                      subtitle: 'Simple, accessible tools for daily routines and emergency help.',
                      onTap: () => context.go('/register?role=patient'),
                    ),
                    const SizedBox(height: 12),
                    _RoleTile(
                      icon: Icons.medical_services_outlined,
                      title: 'Clinician',
                      subtitle: 'Review MRI insights, staging, and patient progress.',
                      onTap: () => context.go('/register?role=doctor'),
                    ),
                    const SizedBox(height: 12),
                    _RoleTile(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Administrator',
                      subtitle: 'Manage users, verify credentials, and oversee platform operations.',
                      onTap: () => context.go('/register?role=admin'),
                    ),
                  ],
                ),
              ),
              if (!isLoggedIn)
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'Already have an account? Log in',
                    style: CareTheme.bodySans.copyWith(
                      color: CareTheme.accentPink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(WidgetRef ref, BuildContext context) async {
    final client = ref.read(supabaseClientProvider);
    await client.auth.signOut();
    ref.invalidate(authSessionProvider);
    ref.invalidate(userProfileProvider);
    if (context.mounted) context.go('/welcome');
  }
}

class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CareTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: CareTheme.accentPink.withValues(alpha: 0.2),
        highlightColor: CareTheme.accentPink.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CareTheme.accentPink.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: CareTheme.accentPink),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: CareTheme.bodySans.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: CareTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle, style: CareTheme.bodySans.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: CareTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
