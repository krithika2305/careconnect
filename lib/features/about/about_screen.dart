import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/care_ui.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              const CareHeartHero(size: 160),

              const SizedBox(height: 20),

              Text(
                "Welcome to CareConnect",
                textAlign: TextAlign.center,
                style: CareTheme.displaySerif.copyWith(
                  fontSize: 32,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                "Helping caregivers, families, and clinicians provide safer, more connected dementia care.",
                textAlign: TextAlign.center,
                style: CareTheme.bodySans.copyWith(
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 40),

              _featureCard(
                Icons.medication_outlined,
                "Medication Reminders",
                "Never miss important medications.",
              ),

              _featureCard(
                Icons.location_on_outlined,
                "Safety Monitoring",
                "Location and wellbeing tracking.",
              ),

              _featureCard(
                Icons.psychology_outlined,
                "AI Cognitive Insights",
                "Track cognitive changes over time.",
              ),

              _featureCard(
                Icons.emergency_outlined,
                "Emergency Support",
                "Quick help when it matters most.",
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  context.push('/role-selection');
                },
                child: const Text("Continue"),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _featureCard(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.teal.withOpacity(0.15),
            child: Icon(
              icon,
              color: Colors.teal,
            ),
          ),

          const SizedBox(width: 16),

          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}