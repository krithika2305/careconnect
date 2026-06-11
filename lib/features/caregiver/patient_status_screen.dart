import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PatientStatusScreen extends StatelessWidget {
  final List<dynamic> records;
  const PatientStatusScreen({super.key, required this.records});

  Color getStatusColor(String status) {
    if (status.contains("Normal")) return MedicalTheme.accentGreen;
    if (status.contains("Concern")) return MedicalTheme.accentOrange;
    return MedicalTheme.accentCoral;
  }

  @override
  Widget build(BuildContext context) {
    // Perform telemetry calculations
    final totalTests = records.length;
    final missedCount = records.where((r) => r["missed_game"] == 1).length;
    
    double avgDuration = 0;
    if (totalTests - missedCount > 0) {
      final totalDuration = records.where((r) => r["missed_game"] != 1).fold<int>(0, (sum, r) => sum + (r["duration"] as int));
      avgDuration = totalDuration / (totalTests - missedCount);
    }

    final normalCount = records.where((r) => r["ai_status"]?.toString().contains("Normal") ?? false).length;
    final stabilityRate = totalTests > 0 ? (normalCount / totalTests) * 100 : 0.0;

    // Get current status description for banner styling
    final latestRecord = records.isNotEmpty ? records.first : null;
    final latestStatus = latestRecord != null ? latestRecord["ai_status"]?.toString() ?? "Normal" : "Normal";
    final isConcern = latestStatus.contains("Concern");
    final isAlert = latestStatus.contains("High") || latestStatus.contains("Delay") || (latestRecord != null && latestRecord["missed_game"] == 1);
    
    Color insightThemeColor = MedicalTheme.accentGreen;
    String insightTitle = "Cognitive State: Stable";
    IconData insightIcon = Icons.check_circle_rounded;
    if (isConcern) {
      insightThemeColor = MedicalTheme.accentOrange;
      insightTitle = "Cognitive State: Watchful";
      insightIcon = Icons.warning_rounded;
    } else if (isAlert) {
      insightThemeColor = MedicalTheme.accentCoral;
      insightTitle = "Cognitive State: High Risk Alert";
      insightIcon = Icons.dangerous_rounded;
    }

    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: const Text("Clinical Telemetry Report"),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Medical Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MedicalTheme.primaryTeal.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 48,
                            color: MedicalTheme.primaryTeal,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "John Doe",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: MedicalTheme.darkSlate,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: MedicalTheme.lightBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Age 74 • Male",
                                      style: TextStyle(color: MedicalTheme.lightSlate, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: MedicalTheme.accentOrange.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: MedicalTheme.accentOrange.withOpacity(0.12)),
                                    ),
                                    child: const Text(
                                      "Stage 1 Dementia",
                                      style: TextStyle(color: MedicalTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(color: Color(0xFFF1F5F9)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildPatientDetailTile("Blood Group", "O-Positive")),
                        const SizedBox(width: 8),
                        Expanded(child: _buildPatientDetailTile("Vitals Sync", "Active Ring")),
                        const SizedBox(width: 8),
                        Expanded(child: _buildPatientDetailTile("Clinic ID", "CC-8829-JD")),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Analytics Section
            const Text(
              "Cognitive Metrics Summary",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MedicalTheme.darkSlate,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: "Total Tests",
                    value: "$totalTests",
                    subtitle: "Logs Completed",
                    icon: Icons.checklist_rounded,
                    color: MedicalTheme.primaryTeal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: "Avg Reaction",
                    value: "${avgDuration.toStringAsFixed(1)}s",
                    subtitle: "Reaction Speed",
                    icon: Icons.speed_rounded,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: "Missed Tests",
                    value: "$missedCount",
                    subtitle: "Prompts Ignored",
                    icon: Icons.event_busy_rounded,
                    color: MedicalTheme.accentCoral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Caregiver Guidance Notes
            const Text(
              "Caregiver Guidance Notes",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MedicalTheme.darkSlate,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: insightThemeColor.withOpacity(0.12), width: 1.5),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      insightThemeColor.withOpacity(0.04),
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: insightThemeColor.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(insightIcon, color: insightThemeColor, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          insightTitle,
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: insightThemeColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      missedCount > 2
                          ? "ALERT: The patient has missed multiple cognitive challenges this week. This is an indicator of memory decline, coordination failures, or phone avoidance. Ensure they attempt the next scheduled challenge and verify that device notifications are audible."
                          : avgDuration > 15
                              ? "WARNING: The average test duration is abnormally elevated at ${avgDuration.toStringAsFixed(1)} seconds. Standard reaction baselines suggest active cognitive delay or fine-motor difficulty. Inform the primary care clinician for potential medication alignment."
                              : "STATUS STABLE: Cognitive assessments indicate strong compliance and prompt reaction speed metrics (${avgDuration.toStringAsFixed(1)} seconds average). The patient's stability rate is currently ${stabilityRate.toStringAsFixed(0)}%. No emergency intervention required.",
                      style: const TextStyle(
                        height: 1.5, 
                        color: MedicalTheme.darkSlate, 
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    const Text(
                      "CLINICAL WORKPLAN CHECKLIST",
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.bold, 
                        color: MedicalTheme.lightSlate,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildChecklistItem("Verify daily bio-ring charging status"),
                    _buildChecklistItem("Prompt cognitive challenge test before 12:00 PM"),
                    _buildChecklistItem("Assess coordination & gait stability during tasks"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientDetailTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: MedicalTheme.lightSlate, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: MedicalTheme.darkSlate),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: MedicalTheme.secondaryMint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: MedicalTheme.lightSlate, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w900, 
                color: MedicalTheme.darkSlate,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: MedicalTheme.darkSlate),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: MedicalTheme.lightSlate),
            ),
          ],
        ),
      ),
    );
  }
}
