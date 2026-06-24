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
              const SizedBox(height: 50),
              const CareHeartHero(size: 185),
              const SizedBox(height: 40),
              Center(
                child: SizedBox(
                  width: 320,
                  child: CareHighlightText(
                    text:
                        "Together, we'll make each day of dementia care a little easier, a little lighter.",
                    highlights: const ['easier', 'lighter'],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 1,
                    color: Colors.teal.shade300,
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.favorite,
                    color: Colors.pink,
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 60,
                    height: 1,
                    color: Colors.teal.shade300,
                  ),
                ],
              ),

              const SizedBox(height: 50),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(220, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(35),
                  ),
                ),
                onPressed: () => context.push('/about'),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(170, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(35),
                  ),
                ),
                onPressed: () => context.push('/login'),
                child: const Text(
                  'Log In',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
