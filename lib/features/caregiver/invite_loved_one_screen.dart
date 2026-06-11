import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/care_ui.dart';
import '../../services/patient_link_service.dart';
import '../../services/providers.dart';

class InviteLovedOneScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSuccess;
  final String? successRoute;
  final bool showSkip;

  const InviteLovedOneScreen({
    super.key,
    this.onSuccess,
    this.successRoute,
    this.showSkip = false,
  });

  @override
  ConsumerState<InviteLovedOneScreen> createState() => _InviteLovedOneScreenState();
}

class _InviteLovedOneScreenState extends ConsumerState<InviteLovedOneScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _inviteCode;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Please enter a valid email address.');
      return;
    }

    setState(() {
      _loading = true;
      if (!_keepInviteCodeVisible) _inviteCode = null;
    });

    try {
      final service = PatientLinkService(ref.read(supabaseClientProvider));
      final result = await service.linkByEmail(
        email: email,
        lovedOneName: _nameController.text.trim(),
      );

      ref.invalidate(myPatientsProvider);
      ref.invalidate(myPendingInvitesProvider);

      if (!mounted) return;

      if (result.isLinked) {
        _snack('Connected successfully! You can now manage their care.');
        _finish();
      } else if (result.isInvited) {
        setState(() => _inviteCode = result.inviteCode);
        _snack('Invite created. Share the code with your loved one.');
      }
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _keepInviteCodeVisible => _inviteCode != null;

  void _finish() {
  if (widget.onSuccess != null) {
    widget.onSuccess!();
  } else if (widget.successRoute != null) {
    context.go(widget.successRoute!);
  } else if (context.canPop()) {
    context.pop();   // ✅ ONLY change: pop instead of go('/caregiver')
  } else {
    context.go('/caregiver');
  }
}

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareHeartHero(size: 96),
        const SizedBox(height: 20),
        Text(
          'Add your loved one',
          textAlign: TextAlign.center,
          style: CareTheme.displaySerif.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 10),
        Text(
          "We'll link their account if they've already joined, or create an invite for their email.",
          textAlign: TextAlign.center,
          style: CareTheme.bodySans.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: CareTheme.textPrimary),
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Their name',
            prefixIcon: Icon(Icons.person_outline, color: CareTheme.textMuted),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: CareTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Their email',
            prefixIcon: Icon(Icons.email_outlined, color: CareTheme.textMuted),
          ),
        ),
        if (_inviteCode != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CareTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CareTheme.accentPink.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(
                  'Invite code',
                  style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _inviteCode!.toUpperCase(),
                  style: CareTheme.displaySerif.copyWith(
                    fontSize: 26,
                    color: CareTheme.accentPink,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask them to sign up as a patient with this email. Pending invites link automatically.',
                  textAlign: TextAlign.center,
                  style: CareTheme.bodySans.copyWith(fontSize: 12, color: CareTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _loading
              ? null
              : (_inviteCode != null ? _finish : _sendInvite),
          child: _loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_inviteCode != null ? 'Continue' : 'Send invite'),
        ),
        if (widget.showSkip) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _finish,
            child: Text(
              'Skip for now',
              style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(CareTheme.darkOverlay);

    if (widget.showSkip) {
      return CareOnboardingShell(
        progress: 0.6,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildFormFields(),
        ),
        bottom: _buildActions(),
      );
    }

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(title: const Text('Link loved one')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _buildFormFields(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _buildActions(),
            ),
          ],
        ),
      ),
    );
  }
}
