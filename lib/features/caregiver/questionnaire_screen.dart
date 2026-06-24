import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'caregiver_dashboard.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  
  final List<Map<String, dynamic>> _questions = [
    {
      "question": "Has the patient recently had difficulty remembering recent events or conversations?",
      "options": [
        {"text": "Never", "score": 0},
        {"text": "Occasionally", "score": 1},
        {"text": "Frequently", "score": 2},
        {"text": "Almost Always", "score": 3},
      ],
    },
    {
      "question": "Does the patient struggle to find the right words or communicate thoughts clearly?",
      "options": [
        {"text": "Never", "score": 0},
        {"text": "Occasionally", "score": 1},
        {"text": "Frequently", "score": 2},
        {"text": "Almost Always", "score": 3},
      ],
    },
    {
      "question": "Have you noticed any confusion regarding time, date, or familiar places?",
      "options": [
        {"text": "Never", "score": 0},
        {"text": "Occasionally", "score": 1},
        {"text": "Frequently", "score": 2},
        {"text": "Almost Always", "score": 3},
      ],
    },
    {
      "question": "Are there sudden mood swings, withdrawal from social activities, or signs of apathy?",
      "options": [
        {"text": "Never", "score": 0},
        {"text": "Occasionally", "score": 1},
        {"text": "Frequently", "score": 2},
        {"text": "Almost Always", "score": 3},
      ],
    },
    {
      "question": "Does the patient have trouble with routine tasks like managing finances, cooking, or personal hygiene?",
      "options": [
        {"text": "Independent", "score": 0},
        {"text": "Needs Some Help", "score": 1},
        {"text": "Needs Regular Help", "score": 2},
        {"text": "Fully Dependent", "score": 3},
      ],
    }
  ];
  

  void _answerQuestion(int score) {
    _score += score;
    
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _showResults();
    }
  }
  
  String _calculateStage() {
    // Total possible score is 15.
    if (_score <= 3) return "No Cognitive Decline (Normal)";
    if (_score <= 7) return "Mild Cognitive Impairment (Very Mild Dementia)";
    if (_score <= 11) return "Moderate Cognitive Decline (Mild to Moderate Dementia)";
    return "Severe Cognitive Decline (Severe Dementia)";
  }

  void _showResults() {
    final stage = _calculateStage();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.analytics, color: MedicalTheme.primaryTeal),
              SizedBox(width: 8),
              Expanded(child: Text("Assessment Complete", style: TextStyle(color: MedicalTheme.darkSlate))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total Score: $_score / 15", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              const Text("Suggested Stage:", style: TextStyle(color: MedicalTheme.lightSlate)),
              const SizedBox(height: 4),
              Text(
                stage, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: MedicalTheme.accentOrange)
              ),
              const SizedBox(height: 12),
              const Text(
                "Note: This assessment provides an early indication of cognitive decline and does not replace professional medical diagnosis.",
                style: TextStyle(fontSize: 12, color: MedicalTheme.lightSlate, fontStyle: FontStyle.italic),
              )
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const CaregiverDashboard()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: MedicalTheme.primaryTeal),
              child: const Text("Return to Dashboard"),
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestionIndex];
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Cognitive Questionnaire"),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: MedicalTheme.darkSlate),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _questions.length,
                backgroundColor: Colors.grey.shade200,
                color: MedicalTheme.primaryTeal,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
              Text(
                "Question ${_currentQuestionIndex + 1} of ${_questions.length}",
                style: const TextStyle(color: MedicalTheme.lightSlate, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              const Text(
                'Please answer based on the patient’s behaviour over the last 30 days.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MedicalTheme.lightSlate,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        question["question"],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: MedicalTheme.darkSlate),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ...(question["options"] as List<Map<String, dynamic>>).map((option) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () => _answerQuestion(option["score"]),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                              ),
                              child: Text(
                                option["text"],
                                style: const TextStyle(color: MedicalTheme.darkSlate, fontSize: 16),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
