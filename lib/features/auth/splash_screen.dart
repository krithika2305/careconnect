import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/care_ui.dart';
import '../../services/auth_navigation.dart';
import '../../services/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(CareTheme.darkOverlay);
    Future.delayed(const Duration(milliseconds: 2200), _navigateNext);
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;

    final session = ref.read(authSessionProvider);
    if (session == null) {
      context.go('/welcome');
      return;
    }

    await navigateAfterAuth(ref, context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const CareHeartHero(size: 160),
              const SizedBox(height: 40),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: CareTheme.displaySerif.copyWith(fontSize: 26),
                  children: const [
                    TextSpan(
                      text: "You're their care partner.\n",
                      style: TextStyle(color: CareTheme.textPrimary),
                    ),
                    TextSpan(
                      text: "We're yours.",
                      style: TextStyle(color: CareTheme.accentPink),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              const CareLoadingDots(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
