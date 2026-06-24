import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../services/auth_navigation.dart';

class PendingVerificationScreen extends ConsumerStatefulWidget {
  final String userRole;

  const PendingVerificationScreen({
    super.key,
    required this.userRole,
  });

  @override
  ConsumerState<PendingVerificationScreen> createState() =>
      _PendingVerificationScreenState();
}

class _PendingVerificationScreenState
    extends ConsumerState<PendingVerificationScreen> {
  @override
  Widget build(BuildContext context) {
    final verificationStatus = ref.watch(myVerificationStatusProvider);

    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: const Text('Account Verification'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              final client = ref.read(supabaseClientProvider);
              await client.auth.signOut();
              ref.invalidate(authSessionProvider);
              ref.invalidate(userProfileProvider);
              if (mounted) context.go('/welcome');
            },
          ),
        ],
      ),
      body: verificationStatus.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $err'),
            ],
          ),
        ),
        data: (status) {
          final verificationStatus = status?['verification_status'] as String?;
          final accountStatus = status?['account_status'] as String?;
          final rejectionReason =
              status?['verification_rejected_reason'] as String?;

          // Determine which content to show based on status
          if (accountStatus == 'SUSPENDED') {
            return _buildSuspendedView(rejectionReason);
          }

          if (verificationStatus == 'VERIFIED') {
            return _buildVerifiedView(
              context,
              widget.userRole,
            );
          }

          if (verificationStatus == 'REJECTED') {
            return _buildRejectedView(rejectionReason, context);
          }

          // PENDING_REVIEW or UNVERIFIED
          return _buildPendingView(context);
        },
      ),
    );
  }

  Widget _buildPendingView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: MedicalTheme.accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: Icon(
                  Icons.schedule_outlined,
                  size: 48,
                  color: MedicalTheme.accentOrange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Account Pending Verification',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MedicalTheme.textPrimary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Thank you for signing up! Your ${widget.userRole} account is currently under review by our admin team.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MedicalTheme.lightSlate,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildStatusCard('Step 1: Review', 'Your credentials are being verified',
              Icons.fact_check_outlined, true),
          const SizedBox(height: 12),
          _buildStatusCard('Step 2: Approval', 'Pending admin review',
              Icons.admin_panel_settings_outlined, false),
          const SizedBox(height: 12),
          _buildStatusCard('Step 3: Access', 'Full platform access granted',
              Icons.lock_open_outlined, false),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MedicalTheme.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MedicalTheme.primaryTeal.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: MedicalTheme.primaryTeal,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Typical Timeline',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: MedicalTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Verification usually takes 1-2 business days. You will receive an email notification once your account is approved.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MedicalTheme.lightSlate,
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MedicalTheme.accentGreen.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MedicalTheme.accentGreen.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: MedicalTheme.accentGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Questions?',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: MedicalTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Contact our support team at support@careconnect.com if you have any questions about the verification process.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MedicalTheme.lightSlate,
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => ref.refresh(myVerificationStatusProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: MedicalTheme.primaryTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Refresh Status',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRejectedView(String? reason, BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  size: 48,
                  color: Colors.red,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Verification Rejected',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (reason != null) ...[
            Text(
              'Reason:',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Text(
                reason,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                      height: 1.5,
                    ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Your verification request was not approved. Please contact support for more information.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MedicalTheme.lightSlate,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Text(
            'Contact Support',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Email: support@careconnect.com',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MedicalTheme.primaryTeal,
                ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                final client = ref.read(supabaseClientProvider);
                await client.auth.signOut();
                ref.invalidate(authSessionProvider);
                ref.invalidate(userProfileProvider);
                if (mounted) context.go('/welcome');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuspendedView(String? reason) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: Icon(
                  Icons.lock_rounded,
                  size: 48,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Account Suspended',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              reason ?? 'Your account has been suspended.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MedicalTheme.lightSlate,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Text(
              'Please contact support@careconnect.com',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MedicalTheme.primaryTeal,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedView(BuildContext context,String? role,) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: MedicalTheme.accentGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 48,
                  color: MedicalTheme.accentGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Account Verified!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.accentGreen,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your account has been approved. You now have full access to CareConnect.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MedicalTheme.lightSlate,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  print('CONTINUE CLICKED');
                  await navigateAfterAuth(ref, context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MedicalTheme.primaryTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue to Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    String title,
    String description,
    IconData icon,
    bool isActive,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? MedicalTheme.accentGreen.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? MedicalTheme.accentGreen.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive
                ? MedicalTheme.accentGreen
                : Colors.grey.withOpacity(0.5),
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? MedicalTheme.textPrimary
                            : MedicalTheme.lightSlate,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MedicalTheme.lightSlate,
                      ),
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MedicalTheme.accentGreen,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'In Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
