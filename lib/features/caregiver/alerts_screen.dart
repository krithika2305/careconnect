import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AlertsScreen extends StatelessWidget {
  final List<dynamic> records;
  const AlertsScreen({super.key, required this.records});

  Color getStatusColor(String status) {
    if (status.contains("Normal")) return MedicalTheme.accentGreen;
    if (status.contains("Concern")) return MedicalTheme.accentOrange;
    return MedicalTheme.accentCoral;
  }

  @override
  Widget build(BuildContext context) {
    // Filter out only critical alerts (Concern, High Risk, or Missed game)
    final criticalRecords = records.where((r) {
      final status = r["ai_status"]?.toString() ?? "";
      return status.contains("High") || status.contains("Concern") || r["missed_game"] == 1;
    }).toList();

    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: const Text("Critical Monitoring Alerts"),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MedicalTheme.accentCoral.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: MedicalTheme.accentCoral,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Active Health Warnings",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.darkSlate,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "Below are the critical warning signals flagged by the AI telemetry algorithms. Please review and coordinate with the physician if changes persist.",
              style: TextStyle(
                color: MedicalTheme.lightSlate,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: criticalRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              size: 56,
                              color: Colors.grey,
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            "No Active Alerts",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: MedicalTheme.darkSlate,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            "Patient is currently safe.\nNo SOS alerts or critical health warnings detected.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: MedicalTheme.lightSlate,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: criticalRecords.length,
                      itemBuilder: (context, index) {
                        final alert = criticalRecords[index];
                        final statusStr = alert["ai_status"]?.toString() ?? "Concern";
                        final isHighRisk = statusStr.contains("High") || alert["missed_game"] == 1;
                        final cardColor = isHighRisk ? MedicalTheme.accentCoral : MedicalTheme.accentOrange;
                        final dateStr = alert["created_at"]?.toString() ?? "";
                        final formattedDate = dateStr.length >= 10 ? dateStr.substring(0, 10) : "N/A";
                        final timeStr = dateStr.length >= 16 ? dateStr.substring(11, 16) : "N/A";

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(color: cardColor.withOpacity(0.15), width: 1.5),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                colors: [
                                  cardColor.withOpacity(0.03),
                                  Colors.white,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardColor.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: cardColor.withOpacity(0.12), width: 1.5),
                                  ),
                                  child: Icon(
                                    isHighRisk ? Icons.dangerous_rounded : Icons.warning_rounded,
                                    color: cardColor,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: cardColor.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isHighRisk ? "CRITICAL RISK" : "WARNING SIGNAL",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: cardColor,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "$formattedDate • $timeStr",
                                            style: const TextStyle(fontSize: 11, color: MedicalTheme.lightSlate, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        statusStr,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: MedicalTheme.darkSlate,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        alert["missed_game"] == 1
                                            ? "IMPLICATION: The patient failed to complete the daily cognitive screening game prompt. This frequently correlates with device neglect, acute memory block, or general cognitive confusion. A physical check-in is recommended."
                                            : "IMPLICATION: The cognitive tapping test took ${alert['duration']} seconds to complete. This is significantly above the baseline threshold, indicating acute reaction delay or fine-motor deficits. Monitor next log closely.",
                                        style: const TextStyle(
                                          fontSize: 13, 
                                          color: MedicalTheme.lightSlate,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
