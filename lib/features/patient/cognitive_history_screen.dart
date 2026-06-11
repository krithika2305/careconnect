import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';

class CognitiveHistoryScreen extends ConsumerWidget {
  const CognitiveHistoryScreen({super.key});

  List<FlSpot> buildSpots(List<dynamic> records) {
    List<FlSpot> spots = [];
    // Only chart the last 10 records to keep it clean and readable
    final displayRecords = records.length > 10 
        ? records.sublist(records.length - 10) 
        : records;
        
    for (int i = 0; i < displayRecords.length; i++) {
      final status = displayRecords[i]["ai_status"]?.toString() ?? "";
      double score = 2.0; // Default concern

      if (status.contains("Normal")) {
        score = 3.0;
      }
      if (status.contains("Concern")) {
        score = 2.0;
      }
      if (status.contains("High") || status.contains("Delay")) {
        score = 1.0;
      }

      spots.add(FlSpot(i.toDouble(), score));
    }
    return spots;
  }

  Color getStatusColor(String status) {
    if (status.contains("Normal")) {
      return MedicalTheme.accentGreen;
    }
    if (status.contains("Concern")) {
      return MedicalTheme.accentOrange;
    }
    return MedicalTheme.accentCoral;
  }

  Widget _buildStatusPill(String status) {
    Color baseColor = getStatusColor(status);
    String text = "Unknown";
    if (status.contains("Normal")) {
      text = "Normal";
    } else if (status.contains("Concern")) {
      text = "Concern";
    } else if (status.contains("High") || status.contains("Delay")) {
      text = "High Risk";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: baseColor.withOpacity(0.16), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: baseColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(cognitiveHistoryProvider);

    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: const Text("Cognitive Analytics"),
        backgroundColor: Colors.white,
      ),
      body: historyAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.psychology_outlined,
                        size: 64,
                        color: MedicalTheme.lightSlate,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "No clinical records yet",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: MedicalTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Your daily cognitive test assessments will appear here to log your response telemetry.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: MedicalTheme.lightSlate,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Calculate clinical stats
          final totalTests = records.length;
          final averageSeconds = records.fold<double>(0.0, (sum, record) {
            final duration = (record["duration"] ?? 0) as num;
            return sum + duration.toDouble();
          }) / totalTests;

          final normalCount = records.where((r) => r["ai_status"]?.toString().contains("Normal") ?? false).length;
          final normalRatio = (normalCount / totalTests) * 100;

          final spots = buildSpots(records);

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Telemetry Overview Cards
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Total Logs",
                                style: TextStyle(fontSize: 11, color: MedicalTheme.lightSlate, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "$totalTests tests",
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: MedicalTheme.darkSlate),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Avg Reaction",
                                style: TextStyle(fontSize: 11, color: MedicalTheme.lightSlate, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "${averageSeconds.toStringAsFixed(1)}s",
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: MedicalTheme.primaryTeal),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Stability Rate",
                                style: TextStyle(fontSize: 11, color: MedicalTheme.lightSlate, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "${normalRatio.toStringAsFixed(0)}%",
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: MedicalTheme.accentGreen),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Chart Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Mental Alertness Score",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: MedicalTheme.darkSlate,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: MedicalTheme.lightBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Last 10 Tests",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: MedicalTheme.lightSlate),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 180,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: const Color(0xFFF1F5F9),
                                  strokeWidth: 1.5,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    reservedSize: 64,
                                    getTitlesWidget: (val, meta) {
                                      String label = "";
                                      if (val == 3.0) {
                                        label = "Normal";
                                      } else if (val == 2.0) {
                                        label = "Concern";
                                      } else if (val == 1.0) {
                                        label = "High Risk";
                                      }
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        space: 8,
                                        child: Text(
                                          label,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: MedicalTheme.lightSlate,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    getTitlesWidget: (val, meta) {
                                      final index = val.toInt();
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        space: 4,
                                        child: Text(
                                          "T-${index + 1}",
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: MedicalTheme.lightSlate,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  tooltipBgColor: MedicalTheme.darkSlate.withOpacity(0.95),
                                  tooltipRoundedRadius: 12,
                                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                    return touchedSpots.map((barSpot) {
                                      final val = barSpot.y;
                                      String status = "Concern";
                                      if (val == 3.0) {
                                        status = "Normal Status";
                                      }
                                      if (val == 2.0) {
                                        status = "Mild Concern";
                                      }
                                      if (val == 1.0) {
                                        status = "High Risk Alert";
                                      }
                                      return LineTooltipItem(
                                        status,
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  gradient: const LinearGradient(
                                    colors: [MedicalTheme.primaryTeal, MedicalTheme.secondaryMint],
                                  ),
                                  barWidth: 4.5,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                      radius: 5,
                                      color: Colors.white,
                                      strokeColor: MedicalTheme.primaryTeal,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        MedicalTheme.primaryTeal.withOpacity(0.15),
                                        MedicalTheme.primaryTeal.withOpacity(0.0),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                              minY: 0.8,
                              maxY: 3.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  "Assessment History Logs",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.darkSlate,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),

                // History List
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      // Reverse order to show latest first
                      final record = records[records.length - 1 - index];
                      final status = record["ai_status"]?.toString() ?? "Unknown";
                      final dateStr = record["created_at"]?.toString() ?? "";
                      final formattedDate = dateStr.length >= 10 ? dateStr.substring(0, 10) : "N/A";
                      final timeStr = dateStr.length >= 16 ? dateStr.substring(11, 16) : "N/A";

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: getStatusColor(status).withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              status.contains("Missed") 
                                  ? Icons.event_busy_rounded 
                                  : Icons.psychology_rounded, 
                              color: getStatusColor(status),
                              size: 24,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  status.split('–').first.split(' - ').first.trim(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: MedicalTheme.darkSlate,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              _buildStatusPill(status),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              record['missed_game'] == 1
                                  ? "Assumed cognitive delay due to skipped log."
                                  : "Speed: ${record['duration']} sec • Registered: $timeStr",
                              style: const TextStyle(fontSize: 12, color: MedicalTheme.lightSlate),
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: MedicalTheme.lightSlate,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: MedicalTheme.lightSlate,
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            "Error fetching trends: $err",
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}