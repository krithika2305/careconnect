import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';

/// Caregiver completes a periodic assessment questionnaire for their patient.
class CaregiverQuestionnaireScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;

  const CaregiverQuestionnaireScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<CaregiverQuestionnaireScreen> createState() =>
      _CaregiverQuestionnaireScreenState();
}

class _CaregiverQuestionnaireScreenState
    extends ConsumerState<CaregiverQuestionnaireScreen> {
  final Map<String, String> _answers = {};
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  static const _options = ['Yes', 'No', 'Sometimes'];

  String _currentPeriod() {
    final now = DateTime.now();
    final quarter = ((now.month - 1) ~/ 3) + 1;
    return 'Q$quarter ${now.year}';
  }

  bool _hasAnsweredAll(List<dynamic> questions) {
    return questions.every((q) => _answers.containsKey(q['id'] as String));
  }

  String _calculateStage(Map<String, String> answers) {
    var score = 0;
    for (final answer in answers.values) {
      if (answer == 'Yes') {
        score += 2;
      } else if (answer == 'Sometimes') {
        score += 1;
      }
    }
    final maxScore = answers.length * 2;
    if (maxScore == 0) return 'No Cognitive Decline (Normal)';
    final ratio = score / maxScore;
    if (ratio <= 0.25) return 'No Cognitive Decline (Normal)';
    if (ratio <= 0.5) {
      return 'Mild Cognitive Impairment (Very Mild Dementia)';
    }
    if (ratio <= 0.75) {
      return 'Moderate Cognitive Decline (Mild to Moderate Dementia)';
    }
    return 'Severe Cognitive Decline (Severe Dementia)';
  }

  Future<void> _submit(List<dynamic> questions) async {
    if (!_hasAnsweredAll(questions)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all questions before submitting.'),
          backgroundColor: MedicalTheme.accentOrange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final client  = ref.read(supabaseClientProvider);
    final session = ref.read(authSessionProvider);

    try {
      final stage = _calculateStage(_answers);
      final response = await client.from('questionnaire_responses').insert({
        'patient_id': widget.patientId,
        'caregiver_id': session!.user.id,
        'period_label': _currentPeriod(),
        'answers': _answers,
        'additional_notes': _notesCtrl.text.trim(),
        'status': 'SUBMITTED',
      }).select('id').single();

      await client.from('patient_stages').insert({
        'patient_id': widget.patientId,
        'response_id': response['id'],
        'assigned_by': session.user.id,
        'stage': stage,
        'stage_notes': 'Auto-assigned from questionnaire ${_currentPeriod()}',
      });

      ref.invalidate(myResponsesProvider);
      ref.invalidate(patientStagesProvider(widget.patientId));
      ref.invalidate(latestPatientStageProvider(widget.patientId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Assessment submitted successfully.'),
            backgroundColor: MedicalTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting: $e'),
            backgroundColor: MedicalTheme.accentCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(questionnaireQuestionsProvider);

    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: Text('Assessment – ${_currentPeriod()}'),
        backgroundColor: Colors.white,
      ),
      body: questionsAsync.when(
        data: (questions) {
          if (questions.isEmpty) {
            return const Center(
              child: Text(
                'No questions available yet.\nAsk your admin to add assessment questions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MedicalTheme.lightSlate),
              ),
            );
          }
          return _buildForm(questions);
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error loading questions: $e')),
      ),
    );
  }

  Widget _buildForm(List<dynamic> questions) {
    // Group by category
    final Map<String, List<dynamic>> grouped = {};
    for (final q in questions) {
      final cat = q['category'] as String? ?? 'General';
      grouped.putIfAbsent(cat, () => []).add(q);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MedicalTheme.primaryTeal.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_rounded,
                        color: MedicalTheme.primaryTeal),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Periodic Assessment for ${widget.patientName}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: MedicalTheme.darkSlate,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Period: ${_currentPeriod()} • ${questions.length} questions',
                          style: const TextStyle(
                              color: MedicalTheme.lightSlate, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Category groups
          for (final entry in grouped.entries) ...[
            _categoryBadge(entry.key),
            const SizedBox(height: 12),
            ...entry.value.map((q) => _questionCard(q)),
            const SizedBox(height: 20),
          ],

          // Additional notes
          const Text(
            'Additional Notes (Optional)',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: MedicalTheme.darkSlate,
                fontSize: 15),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'Any observations, changes in behaviour, or context you\'d like to add…',
              labelText: 'Notes',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => _submit(questions),
              child: _isSubmitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Submitting…'),
                      ],
                    )
                  : const Text('Submit Assessment'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _categoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: MedicalTheme.primaryTeal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: MedicalTheme.primaryTeal,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _questionCard(Map<String, dynamic> q) {
    final id       = q['id'] as String;
    final question = q['question'] as String;
    final answer   = _answers[id];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(
                  color: MedicalTheme.darkSlate,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: _options
                  .map((opt) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _optionButton(id, opt, answer == opt),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionButton(String id, String label, bool selected) {
    Color color;
    switch (label) {
      case 'Yes':
        color = MedicalTheme.accentGreen;
        break;
      case 'No':
        color = MedicalTheme.accentCoral;
        break;
      default:
        color = MedicalTheme.accentOrange;
    }

    return GestureDetector(
      onTap: () => setState(() => _answers[id] = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
