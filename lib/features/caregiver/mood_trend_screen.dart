import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../shared/mood_utils.dart';
import 'widgets/caregiver_ui.dart';

class MoodTrendScreen extends ConsumerWidget {
  final String patientId;
  final String patientName;

  const MoodTrendScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  String _shortDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(moodLogsTrendProvider(patientId));

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        title: Text('Mood & energy — $patientName'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: logsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: CareTheme.accentPink),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: CaregiverDarkCard(
                  child: Text(
                    'No mood check-ins yet. Ask your loved one to tap an emoji on their dashboard twice a day.',
                    textAlign: TextAlign.center,
                    style: CareTheme.bodySans.copyWith(fontSize: 14),
                  ),
                ),
              ),
            );
          }

          final energySpots = <FlSpot>[];
          final moodSpots = <FlSpot>[];
          for (var i = 0; i < logs.length; i++) {
            final energy = (logs[i]['energy_level'] as num?)?.toDouble() ?? 3;
            final mood = logs[i]['mood']?.toString() ?? 'neutral';
            energySpots.add(FlSpot(i.toDouble(), energy));
            moodSpots.add(FlSpot(i.toDouble(), MoodUtils.moodScore(mood)));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Last 14 days',
                style: CareTheme.bodySans.copyWith(
                  fontSize: 14,
                  color: CareTheme.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              CaregiverDarkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Energy level (1–5)',
                      style: CareTheme.bodySans.copyWith(
                        fontWeight: FontWeight.w700,
                        color: CareTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          minY: 1,
                          maxY: 5,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: CareTheme.surfaceLight,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (v, _) => Text(
                                  v.toInt().toString(),
                                  style: CareTheme.bodySans.copyWith(fontSize: 10),
                                ),
                              ),
                            ),
                            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: energySpots,
                              isCurved: true,
                              color: CareTheme.warning,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: CareTheme.warning.withValues(alpha: 0.12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CaregiverDarkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mood wellbeing trend',
                      style: CareTheme.bodySans.copyWith(
                        fontWeight: FontWeight.w700,
                        color: CareTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Higher is better (happy → sad/sick)',
                      style: CareTheme.bodySans.copyWith(fontSize: 12, color: CareTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          minY: 1,
                          maxY: 5,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: CareTheme.surfaceLight,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (v, _) => Text(
                                  v.toInt().toString(),
                                  style: CareTheme.bodySans.copyWith(fontSize: 10),
                                ),
                              ),
                            ),
                            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: moodSpots,
                              isCurved: true,
                              color: CareTheme.accentPink,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: CareTheme.accentPink.withValues(alpha: 0.12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Recent check-ins',
                style: CareTheme.bodySans.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CareTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...logs.reversed.take(20).map((log) {
                final mood = log['mood']?.toString() ?? 'neutral';
                final energy = log['energy_level'] ?? 3;
                final at = log['logged_at']?.toString();
                final local = DateTime.tryParse(at ?? '')?.toLocal();
                final slot = local != null && moodLogIsMorningSlot(local) ? 'Morning' : 'Evening';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CaregiverDarkCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Text(MoodUtils.emoji(mood), style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${MoodUtils.label(mood)} · $slot',
                                style: CareTheme.bodySans.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: CareTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Energy $energy/5 · ${_shortDate(at)}',
                                style: CareTheme.bodySans.copyWith(
                                  fontSize: 12,
                                  color: CareTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
