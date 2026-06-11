import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../shared/questionnaire_scoring.dart';
import 'doctor_prescription_screen.dart';
import '../../services/notification_service.dart';

/// Clinical tools for a selected patient (trends, staging, prescriptions list).
class DoctorClinicalPanel extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;

  const DoctorClinicalPanel({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<DoctorClinicalPanel> createState() => _DoctorClinicalPanelState();
}

class _DoctorClinicalPanelState extends ConsumerState<DoctorClinicalPanel> {
  static const _stageOptions = [
    'Non Demented',
    'Very Mild',
    'Mild',
    'Moderate',
    'Severe',
  ];

  bool _assigningStage = false;

  Future<void> _assignStage() async {
    String selected = _stageOptions.first;
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: CareTheme.surface,
          title: Text('Assign dementia stage', style: CareTheme.displaySerif.copyWith(fontSize: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selected,
                isExpanded: true,
                dropdownColor: CareTheme.surface,
                iconEnabledColor: CareTheme.textPrimary,
                style: CareTheme.dropdownItemStyle,
                decoration: const InputDecoration(labelText: 'Clinical stage'),
                items: _stageOptions
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, style: CareTheme.dropdownItemStyle),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialog(() => selected = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Clinical notes (optional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _assigningStage = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final session = ref.read(authSessionProvider);
      final responses =
          await ref.read(patientQuestionnaireResponsesProvider(widget.patientId).future);
      final latestResponseId =
          responses.isNotEmpty ? responses.last['id']?.toString() : null;

      await client.from('patient_stages').insert({
        'patient_id': widget.patientId,
        'response_id': latestResponseId,
        'assigned_by': session?.user.id,
        'stage': selected,
        'stage_notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      });
      // ── 🔔 Notify caregiver about stage change ──
      try {
        final caregiverMapping = await client
            .from('caregiver_patient_mapping')
            .select('caregiver_id')
            .eq('patient_id', widget.patientId)
            .maybeSingle();
        final caregiverId = caregiverMapping?['caregiver_id'] as String?;
        if (caregiverId != null) {
          await NotificationService.send(
            userId: caregiverId,
            title: '🧠 Stage Updated',
            body: 'Your patient\'s Alzheimer\'s stage has been updated to: $selected',
            type: 'stage_update',
            data: {'patient_id': widget.patientId, 'stage': selected},
          );
        }
        // ── 🔔 Notify patient too ──
        await NotificationService.send(
          userId: widget.patientId,
          title: '🧠 Care Stage Updated',
          body: 'Your doctor has updated your care stage to: $selected',
          type: 'stage_update',
          data: {'stage': selected},
        );
      } catch (_) {}
      ref.invalidate(patientStagesProvider(widget.patientId));
      ref.invalidate(latestPatientStageProvider(widget.patientId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stage updated to $selected'),
            backgroundColor: CareTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not assign stage: $e'), backgroundColor: CareTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _assigningStage = false);
    }
  }

  Future<void> _openPrescriptionWriter() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPrescriptionScreen(
          patientId: widget.patientId,
          patientName: widget.patientName,
        ),
      ),
    );
    if (saved == true && mounted) {
      ref.invalidate(patientPrescriptionsProvider(widget.patientId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsesAsync = ref.watch(patientQuestionnaireResponsesProvider(widget.patientId));
    final mriAsync = ref.watch(patientMriHistoryProvider(widget.patientId));
    final stageAsync = ref.watch(latestPatientStageProvider(widget.patientId));
    final rxAsync = ref.watch(patientPrescriptionsProvider(widget.patientId));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clinical record — ${widget.patientName}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: MedicalTheme.darkSlate,
          ),
        ),
        const SizedBox(height: 16),
        _buildCognitiveTrend(responsesAsync, mriAsync),
        const SizedBox(height: 20),
        _buildStageCard(stageAsync),
        const SizedBox(height: 20),
        _buildPrescriptionsList(rxAsync),
      ],
    );
  }

  Widget _buildCognitiveTrend(
    AsyncValue<List<dynamic>> responsesAsync,
    AsyncValue<List<dynamic>> mriAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cognitive assessment trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MedicalTheme.darkSlate),
            ),
            const SizedBox(height: 4),
            const Text(
              'Questionnaire score over time (higher = more concerns)',
              style: TextStyle(fontSize: 12, color: MedicalTheme.lightSlate),
            ),
            const SizedBox(height: 16),
            responsesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => Text('Error: $e'),
              data: (responses) {
                if (responses.isEmpty) {
                  return const Text(
                    'No questionnaire submissions yet for this patient.',
                    style: TextStyle(color: MedicalTheme.lightSlate),
                  );
                }

                if (responses.length == 1) {
                  final score = scoreQuestionnaireAnswers(responses[0]['answers']);
                  final date = formatSubmittedDate(responses[0]['submitted_at']?.toString());
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CareTheme.accentPink.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              score.toString(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: CareTheme.accentPink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Latest score',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MedicalTheme.lightSlate,
                                ),
                              ),
                              Text(
                                date,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: MedicalTheme.darkSlate,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Need more submissions to show trend',
                        style: TextStyle(
                          fontSize: 11,
                          color: MedicalTheme.lightSlate,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  );
                }

                final spots = <FlSpot>[];
                for (var i = 0; i < responses.length; i++) {
                  spots.add(FlSpot(
                    i.toDouble(),
                    scoreQuestionnaireAnswers(responses[i]['answers']).toDouble(),
                  ));
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 220,
                      child: IgnorePointer(
                        child: LineChart(
                          LineChartData(
                            lineTouchData: const LineTouchData(enabled: false),
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
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: MedicalTheme.lightSlate,
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  getTitlesWidget: (v, _) {
                                    final i = v.toInt();
                                    if (i < 0 || i >= responses.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final label = formatSubmittedDate(
                                      responses[i]['submitted_at']?.toString(),
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        label.length >= 5 ? label.substring(5) : label,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: MedicalTheme.lightSlate,
                                        ),
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
                                spots: spots,
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
                    ),
                    const SizedBox(height: 12),
                    mriAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (mris) {
                        if (mris.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'MRI AI staging events',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MedicalTheme.darkSlate,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: mris.take(6).map((m) {
                                final pred = m['prediction']?.toString() ?? 'MRI';
                                final date = formatSubmittedDate(m['created_at']?.toString());
                                return Chip(
                                  avatar: const Icon(Icons.document_scanner_outlined, size: 16),
                                  label: Text(
                                    '$pred · $date',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: CareTheme.accentPeach.withValues(alpha: 0.2),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageCard(AsyncValue<Map<String, dynamic>?> stageAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dementia stage',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MedicalTheme.darkSlate),
            ),
            const SizedBox(height: 12),
            stageAsync.when(
              loading: () => const SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => Text('Error: $e'),
              data: (stage) {
                final label = stage?['stage']?.toString() ?? 'Not assigned';
                final date = formatSubmittedDate(stage?['assigned_at']?.toString());
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.psychology_outlined, color: CareTheme.accentPink, size: 36),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: MedicalTheme.darkSlate,
                            ),
                          ),
                          if (date.isNotEmpty)
                            Text(
                              'Last updated $date',
                              style: const TextStyle(fontSize: 12, color: MedicalTheme.lightSlate),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _assigningStage ? null : _assignStage,
                icon: _assigningStage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
                label: Text(_assigningStage ? 'Saving…' : 'Assign / update stage'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionsList(AsyncValue<List<Map<String, dynamic>>> rxAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prescriptions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MedicalTheme.darkSlate),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openPrescriptionWriter,
                icon: const Icon(Icons.medication_outlined),
                label: const Text('Write new prescription'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Active prescriptions',
              style: TextStyle(fontWeight: FontWeight.w600, color: MedicalTheme.darkSlate),
            ),
            const SizedBox(height: 10),
            rxAsync.when(
              loading: () => const SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => Text('Error: $e'),
              data: (list) {
                final active = list.where((r) => r['is_active'] == true).toList();
                if (active.isEmpty) {
                  return const Text(
                    'No active prescriptions.',
                    style: TextStyle(color: MedicalTheme.lightSlate),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: active.map((rx) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CareTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CareTheme.surfaceLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rx['medication_name']?.toString() ?? 'Medication',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: MedicalTheme.darkSlate,
                            ),
                          ),
                          Text(
                            [
                              if (rx['dosage'] != null) rx['dosage'],
                              if (rx['frequency'] != null) rx['frequency'],
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12, color: MedicalTheme.lightSlate),
                          ),
                          if (rx['instructions'] != null)
                            Text(
                              rx['instructions'].toString(),
                              style: const TextStyle(fontSize: 12, color: MedicalTheme.lightSlate),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
