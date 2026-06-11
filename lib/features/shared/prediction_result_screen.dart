import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PredictionResultScreen extends StatelessWidget {
  final String? imagePath;
  final String prediction;
  final double confidence;

  const PredictionResultScreen({
    super.key,
    this.imagePath,
    required this.prediction,
    required this.confidence,
  });

  String _getMedicalRecommendations(String stage) {
    if (stage.toLowerCase().contains("non") || stage.toLowerCase().contains("normal")) {
      return "• Maintain a healthy lifestyle with regular exercise.\n• Engage in cognitive stimulating activities.\n• Continue routine annual checkups.";
    } else if (stage.toLowerCase().contains("very mild") || stage.toLowerCase().contains("mild")) {
      return "• Schedule a comprehensive cognitive assessment.\n• Discuss early interventions and lifestyle modifications.\n• Begin organizing a long-term care strategy.";
    } else {
      return "• Implement a specialized neuro-care plan.\n• Ensure patient safety with continuous monitoring.\n• Explore caregiver support programs and therapies.";
    }
  }

  Color _getStageColor(String stage) {
    if (stage.toLowerCase().contains("non") || stage.toLowerCase().contains("normal")) {
      return MedicalTheme.accentGreen;
    } else if (stage.toLowerCase().contains("very mild") || stage.toLowerCase().contains("mild")) {
      return MedicalTheme.accentOrange;
    } else {
      return MedicalTheme.accentCoral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stageColor = _getStageColor(prediction);

    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: const Text("Analysis Results"),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview Card
            Hero(
              tag: 'mri_preview',
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: imagePath != null
                    ? Image.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                      )
                    : const Center(
                        child: Icon(
                          Icons.image_not_supported_rounded,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),

            // Prediction Result
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: stageColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.analytics_rounded, color: stageColor),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "AI Classification",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: MedicalTheme.lightSlate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        prediction,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: stageColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Network Confidence",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: MedicalTheme.darkSlate,
                            ),
                          ),
                          Text(
                            "${confidence.toStringAsFixed(1)}%",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: MedicalTheme.primaryTeal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: confidence / 100),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutQuart,
                          builder: (context, value, child) {
                            return LinearProgressIndicator(
                              value: value,
                              color: MedicalTheme.primaryTeal,
                              backgroundColor: const Color(0xFFF1F5F9),
                              minHeight: 8,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Clinical Recommendations
            _buildInfoCard(
              title: "Clinical Recommendations",
              icon: Icons.health_and_safety_rounded,
              content: _getMedicalRecommendations(prediction),
              iconColor: MedicalTheme.secondaryMint,
            ),
            const SizedBox(height: 16),

            // Doctor Consultation
            _buildInfoCard(
              title: "Specialist Consultation",
              icon: Icons.medical_services_rounded,
              content: "This is an AI-assisted preliminary evaluation. Please share this report with a licensed neurologist or cognitive specialist for formal clinical correlation and diagnosis.",
              iconColor: MedicalTheme.primaryTeal,
            ),
            const SizedBox(height: 16),

            // Emergency Guidance
            _buildInfoCard(
              title: "Emergency Guidelines",
              icon: Icons.warning_rounded,
              content: "If the patient exhibits sudden confusion, severe aggression, extreme lethargy, or inability to recognize familiar environments, seek immediate emergency medical attention.",
              iconColor: MedicalTheme.accentCoral,
              isAlert: true,
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: MedicalTheme.primaryTeal,
                  elevation: 0,
                ),
                child: const Text(
                  "Acknowledge & Close",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required String content,
    required Color iconColor,
    bool isAlert = false,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isAlert ? BorderSide(color: MedicalTheme.accentCoral.withOpacity(0.3), width: 1.5) : BorderSide.none,
      ),
      elevation: 0,
      color: isAlert ? MedicalTheme.accentCoral.withOpacity(0.04) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isAlert ? MedicalTheme.accentCoral : MedicalTheme.darkSlate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: MedicalTheme.lightSlate,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
