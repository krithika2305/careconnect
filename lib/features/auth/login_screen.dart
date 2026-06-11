import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../services/auth_navigation.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool isPasswordVisible = false;



  Future<void> loginUser() async {
  final email = emailController.text.trim();
  final password = passwordController.text.trim();

  // 1. Basic empty checks
  if (email.isEmpty || password.isEmpty) {
    _showError('Please enter your email and password.');
    return;
  }

  // 2. Email format validation
  if (!_isValidEmail(email)) {
    _showError('Please enter a valid email address (e.g., name@example.com).');
    return;
  }

  setState(() => isLoading = true);

  try {
    final client = ref.read(supabaseClientProvider);
    await client.auth
        .signInWithPassword(email: email, password: password)
        .timeout(const Duration(seconds: 15));

    if (!mounted) return;
    await navigateAfterAuth(ref, context);
  } on TimeoutException {
    if (mounted) {
      _showError('Connection timed out. Check your internet and try again.');
    }
  } catch (e) {
    if (mounted) {
      _showError(e.toString());
    }
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}

// Helper: email regex
bool _isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.canPop() ? context.pop() : context.go('/welcome'),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: CareTheme.textSecondary, size: 20),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: 0.35,
                  child: Icon(Icons.favorite_border_rounded,
                      size: 72, color: CareTheme.accentPink.withValues(alpha: 0.8)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Welcome to\nCareConnect",
                style: CareTheme.displaySerif.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                'Your hub to coordinate dementia care with confidence.',
                style: CareTheme.bodySans.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: CareTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: CareTheme.textMuted),
                ),
              ),
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isLoading ? null : loginUser,
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.email_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Continue with email'),
                        ],
                      ),
              ),
              const SizedBox(height: 28),
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy.',
                textAlign: TextAlign.center,
                style: CareTheme.bodySans.copyWith(fontSize: 12, color: CareTheme.textMuted),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.push('/role-selection'),
                child: Text(
                  'New here? Create an account',
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


