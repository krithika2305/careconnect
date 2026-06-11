import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class CognitiveTrendScreen extends ConsumerWidget {
  final String patientId;
  final String patientName;

  const CognitiveTrendScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  static int _scoreResponse(Map<String, dynamic> response) {
    final answers = response['answers'];
    if (answers is! Map) return 0;
    var score = 0;
    for (final v in answers.values) {
      if (v == 'Yes') {
        score += 2;
      } else if (v == 'Sometimes') {
        score += 1;
      }
    }
    return score;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsesAsync = ref.watch(patientQuestionnaireResponsesProvider(patientId));
    final stagesAsync = ref.watch(patientStagesProvider(patientId));

    return Theme(
      data: CareTheme.lightTheme,
      child: Scaffold(
        backgroundColor: CareTheme.background,
        appBar: AppBar(
          title: Text('Trend — $patientName', style: CareTheme.displaySerif.copyWith(fontSize: 18)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: responsesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: CareTheme.accentPink),
          ),
          error: (e, _) => Center(child: Text('Error: $e', style: CareTheme.bodySans)),
          data: (responses) {
            if (responses.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Assessment scores over time',
                    style: CareTheme.bodySans.copyWith(
                      fontSize: 14,
                      color: CareTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const CaregiverTrendEmpty(),
                ],
              );
            }

            if (responses.length == 1) {
              final score = _scoreResponse(responses[0]);
              final date = responses[0]['submitted_at']?.toString() ?? '';
              final formattedDate = date.length >= 10 ? date.substring(0, 10) : '';
              final label = responses[0]['period_label']?.toString() ?? formattedDate;
              
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Assessment scores over time',
                    style: CareTheme.bodySans.copyWith(
                      fontSize: 14,
                      color: CareTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: CareTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: CareTheme.accentPink.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                score.toString(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: CareTheme.accentPink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Latest score',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CareTheme.textMuted,
                                  ),
                                ),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: MedicalTheme.darkSlate,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Need more submissions to show trend',
                          style: TextStyle(
                            fontSize: 12,
                            color: CareTheme.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Stage history',
                    style: CareTheme.bodySans.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  stagesAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('Could not load stages'),
                    data: (stages) {
                      if (stages.isEmpty) {
                        return Text(
                          'No stages recorded yet.',
                          style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted),
                        );
                      }
                      return Column(
                        children: stages.map((s) {
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: CareTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['stage']?.toString() ?? 'Unknown',
                                  style: CareTheme.bodySans.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  s['assigned_at']?.toString().substring(0, 10) ?? '',
                                  style: CareTheme.bodySans.copyWith(
                                    fontSize: 11,
                                    color: CareTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
            }

            final scores = <FlSpot>[];
            for (var i = 0; i < responses.length; i++) {
              scores.add(FlSpot(i.toDouble(), _scoreResponse(responses[i]).toDouble()));
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Assessment scores over time',
                  style: CareTheme.bodySans.copyWith(
                    fontSize: 14,
                    color: CareTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
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
                            reservedSize: 28,
                            getTitlesWidget: (v, _) => Text(
                              v.toInt().toString(),
                              style: CareTheme.bodySans.copyWith(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= responses.length) {
                                return const SizedBox.shrink();
                              }
                              final label = responses[i]['period_label']?.toString() ?? '';
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  label.length > 6 ? label.substring(0, 6) : label,
                                  style: CareTheme.bodySans.copyWith(fontSize: 9),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: scores,
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
                const SizedBox(height: 28),
                Text(
                  'Stage history',
                  style: CareTheme.bodySans.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                stagesAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Could not load stages'),
                  data: (stages) {
                    if (stages.isEmpty) {
                      return Text(
                        'No stages recorded yet.',
                        style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted),
                      );
                    }
                    return Column(
                      children: stages.map((s) {
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: CareTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['stage']?.toString() ?? 'Unknown',
                                style: CareTheme.bodySans.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                s['assigned_at']?.toString().substring(0, 10) ?? '',
                                style: CareTheme.bodySans.copyWith(
                                  fontSize: 11,
                                  color: CareTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CaregiverTrendEmpty extends StatelessWidget {
  const CaregiverTrendEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CareTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Complete a questionnaire to see trends here.',
        textAlign: TextAlign.center,
        style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted),
      ),
    );
  }
}
