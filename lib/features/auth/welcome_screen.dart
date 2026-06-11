import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/care_ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(CareTheme.darkOverlay);

    return Scaffold(
      backgroundColor: CareTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const CareHeartHero(size: 150),
              const SizedBox(height: 36),
              CareHighlightText(
                text: "Together, we'll make each day of dementia care a little easier, a little lighter.",
                highlights: const ['easier', 'lighter'],
              ),
              const Spacer(flex: 3),
              ElevatedButton(
                onPressed: () => context.push('/role-selection'),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => context.push('/login'),
                child: const Text('Log In'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
