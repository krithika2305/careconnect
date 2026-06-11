import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("About CareConnect", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0091D5),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0091D5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_hospital, size: 80, color: Color(0xFF0091D5)),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Our Mission",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "CareConnect is a comprehensive healthcare management platform dedicated to bridging the gap between patients, caregivers, and medical professionals. Our mission is to leverage advanced technology, including AI, to provide better monitoring, diagnosis, and care for those suffering from cognitive decline and Alzheimer's disease.",
                  style: TextStyle(
                    fontSize: 16,
                    color: MedicalTheme.lightSlate,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Features",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFeature(Icons.psychology, "AI-Powered Diagnostics", "Utilize advanced machine learning to analyze MRI scans for early detection of cognitive decline."),
                _buildFeature(Icons.family_restroom, "Caregiver Tools", "Empower caregivers with intuitive dashboards, telemetry monitoring, and cognitive assessment tools."),
                _buildFeature(Icons.local_hospital, "Clinical Integration", "Seamlessly connect patients with their doctors to provide holistic and continuous care."),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0091D5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0091D5), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: MedicalTheme.lightSlate,
                    height: 1.5,
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
