import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../services/patient_link_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/auth_navigation.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String initialRole;
  final bool forceCompleteProfile;

  const RegisterScreen({
    super.key,
    this.initialRole = 'caregiver',
    this.forceCompleteProfile = false,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  late String selectedRole;
  bool isLoading = false;
  bool isPasswordVisible = false;
  bool _completingProfile = false;

  @override
  void initState() {
    super.initState();
    selectedRole = widget.initialRole;
    final session = ref.read(supabaseClientProvider).auth.currentSession;
    if (session != null || widget.forceCompleteProfile) {
      _completingProfile = true;
      emailController.text = session?.user.email ?? '';
    }
  }

  String get _roleLabel {
    switch (selectedRole) {
      case 'patient':
        return 'Person Receiving Care';
      case 'doctor':
        return 'Clinician';
      default:
        return 'Care Partner';
    }
  }

  Future<void> registerUser() async {
  final name = nameController.text.trim();
  final email = emailController.text.trim();
  final password = passwordController.text.trim();

  // 1. Name validation
  if (name.isEmpty) {
    _showError('Please enter your full name.');
    return;
  }
  if (name.length < 2) {
    _showError('Name must be at least 2 characters.');
    return;
  }

  // 2. Email validation
  if (email.isEmpty) {
    _showError('Please enter your email address.');
    return;
  }
  if (!_isValidEmail(email)) {
    _showError('Please enter a valid email address (e.g., name@example.com).');
    return;
  }

  // 3. Password validation (only if not completing profile)
  if (!_completingProfile) {
    if (password.isEmpty) {
      _showError('Please enter a password.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters long.');
      return;
    }
    if (!_isStrongPassword(password)) {
      _showError('Password must contain at least one uppercase letter, one lowercase letter, and one number.');
      return;
    }
  }

  setState(() => isLoading = true);

  try {
    final client = ref.read(supabaseClientProvider);
    final existingSession = client.auth.currentSession;

    if (_completingProfile && existingSession != null) {
      await UserProfileService(client).save(
        userId: existingSession.user.id,
        name: name,
        role: selectedRole,
        email: email,
      );
      await client.auth.updateUser(
        UserAttributes(data: {'role': selectedRole}),
      );
    } else {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'role': selectedRole, 'name': name},
      );
      final user = response.user;
      if (user == null) {
        throw Exception('Sign up did not return a user. If this email already exists, use Log in instead.');
      }
      await UserProfileService(client).save(
        userId: user.id,
        name: name,
        role: selectedRole,
        email: email,
      );
      if (selectedRole == 'patient') {
        await PatientLinkService.acceptPendingInvites(client);
        ref.invalidate(myPatientsProvider);
      }
    }

    ref.invalidate(userProfileProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _completingProfile
                ? 'Profile saved. Welcome to CareConnect!'
                : 'Account created. Welcome to CareConnect!',
          ),
        ),
      );
      await navigateAfterAuth(ref, context);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save account: $e\n\nIf this persists, run supabase_users_rls_fix.sql in Supabase.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isStrongPassword(String password) {
    return RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(CareTheme.darkOverlay);

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        title: Text('Join as $_roleLabel'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _completingProfile ? 'Finish your profile' : 'Create your account',
                style: CareTheme.displaySerif.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                _completingProfile
                    ? 'Choose your details below to unlock the app.'
                    : 'Set up your profile to start coordinating care.',
                style: CareTheme.bodySans.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: CareTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline, color: CareTheme.textMuted),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                readOnly: _completingProfile,
                style: const TextStyle(color: CareTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: CareTheme.textMuted),
                ),
              ),
              if (!_completingProfile) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  style: const TextStyle(color: CareTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: CareTheme.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: CareTheme.textMuted,
                      ),
                      onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: isLoading ? null : registerUser,
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_completingProfile ? 'Save and continue' : 'Create account'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.push('/login'),
                child: Text(
                  'Already registered? Log in',
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
}
