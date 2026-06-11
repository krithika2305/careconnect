import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import '../auth/login_screen.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final client = ref.read(supabaseClientProvider);
    await client.auth.signOut();
    ref.invalidate(authSessionProvider);
    ref.invalidate(userProfileProvider);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: MedicalTheme.primaryTeal,
          unselectedLabelColor: MedicalTheme.lightSlate,
          indicatorColor: MedicalTheme.primaryTeal,
          tabs: const [
            Tab(icon: Icon(Icons.help_outline_rounded), text: 'Questions'),
            Tab(icon: Icon(Icons.assignment_turned_in_outlined), text: 'Responses'),
            Tab(icon: Icon(Icons.medical_information_outlined), text: 'Staging'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _QuestionsTab(),
          _ResponsesTab(),
          _StagingTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 1 – Manage Questions
// ─────────────────────────────────────────────────────────────

class _QuestionsTab extends ConsumerWidget {
  const _QuestionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(allQuestionsAdminProvider);

    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuestionDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
        backgroundColor: MedicalTheme.primaryTeal,
      ),
      body: questionsAsync.when(
        data: (questions) {
          if (questions.isEmpty) {
            return const Center(
              child: Text('No questions yet. Tap + to add one.',
                  style: TextStyle(color: MedicalTheme.lightSlate)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: questions.length,
            itemBuilder: (_, i) => _QuestionCard(
              question: questions[i],
              onEdit: () =>
                  _showQuestionDialog(context, ref, existing: questions[i]),
              onToggle: () => _toggleActive(ref, questions[i]),
              onDelete: () => _deleteQuestion(context, ref, questions[i]['id']),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _toggleActive(WidgetRef ref, Map<String, dynamic> q) async {
    final client = ref.read(supabaseClientProvider);
    await client
        .from('questionnaire_questions')
        .update({'is_active': !(q['is_active'] as bool)})
        .eq('id', q['id']);
    ref.invalidate(allQuestionsAdminProvider);
    ref.invalidate(questionnaireQuestionsProvider);
  }

  Future<void> _deleteQuestion(
      BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Question?'),
        content:
            const Text('This cannot be undone. Existing responses will retain their data.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: MedicalTheme.accentCoral)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(supabaseClientProvider)
          .from('questionnaire_questions')
          .delete()
          .eq('id', id);
      ref.invalidate(allQuestionsAdminProvider);
      ref.invalidate(questionnaireQuestionsProvider);
    }
  }

  void _showQuestionDialog(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _QuestionFormSheet(existing: existing, ref: ref),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final Map<String, dynamic> question;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.question,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = question['is_active'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: MedicalTheme.primaryTeal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '#${question['sort_order']}',
            style: const TextStyle(
                color: MedicalTheme.primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 12),
          ),
        ),
        title: Text(
          question['question'] as String,
          style: TextStyle(
            color: isActive ? MedicalTheme.darkSlate : MedicalTheme.lightSlate,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          question['category'] as String? ?? 'General',
          style: const TextStyle(
              color: MedicalTheme.lightSlate, fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'toggle') onToggle();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
                value: 'toggle',
                child: Text(isActive ? 'Deactivate' : 'Activate')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: MedicalTheme.accentCoral))),
          ],
        ),
      ),
    );
  }
}

class _QuestionFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final WidgetRef ref;

  const _QuestionFormSheet({this.existing, required this.ref});

  @override
  State<_QuestionFormSheet> createState() => _QuestionFormSheetState();
}

class _QuestionFormSheetState extends State<_QuestionFormSheet> {
  final _questionCtrl = TextEditingController();
  final _orderCtrl    = TextEditingController();
  String _category    = 'General';
  bool _isSaving      = false;

  static const _categories = [
    'General', 'Memory', 'Orientation', 'Daily Living',
    'Behaviour', 'Communication', 'Cognitive'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _questionCtrl.text = widget.existing!['question'] ?? '';
      _category          = widget.existing!['category'] ?? 'General';
      _orderCtrl.text    = widget.existing!['sort_order']?.toString() ?? '0';
    }
  }

  Future<void> _save() async {
    if (_questionCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    final client  = widget.ref.read(supabaseClientProvider);
    final session = widget.ref.read(authSessionProvider);
    final payload = {
      'question':   _questionCtrl.text.trim(),
      'category':   _category,
      'sort_order': int.tryParse(_orderCtrl.text) ?? 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      if (widget.existing != null) {
        await client
            .from('questionnaire_questions')
            .update(payload)
            .eq('id', widget.existing!['id']);
      } else {
        await client.from('questionnaire_questions').insert({
          ...payload,
          'is_active':  true,
          'created_by': session?.user.id,
        });
      }
      widget.ref.invalidate(allQuestionsAdminProvider);
      widget.ref.invalidate(questionnaireQuestionsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving question: $e'),
            backgroundColor: MedicalTheme.accentCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing != null ? 'Edit Question' : 'New Question',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MedicalTheme.darkSlate),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _questionCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Question Text'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'General'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _orderCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sort Order'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Question'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 2 – Review Responses
// ─────────────────────────────────────────────────────────────

class _ResponsesTab extends ConsumerWidget {
  const _ResponsesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsesAsync = ref.watch(allResponsesAdminProvider);

    return responsesAsync.when(
      data: (responses) {
        if (responses.isEmpty) {
          return const Center(
            child: Text('No responses submitted yet.',
                style: TextStyle(color: MedicalTheme.lightSlate)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: responses.length,
          itemBuilder: (_, i) => _ResponseCard(
            response: responses[i],
            onView: () => _viewResponse(context, responses[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _viewResponse(BuildContext context, Map<String, dynamic> response) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ResponseDetailSheet(response: response),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  final Map<String, dynamic> response;
  final VoidCallback onView;

  const _ResponseCard({required this.response, required this.onView});

  @override
  Widget build(BuildContext context) {
    final patientName =
        (response['patient_profiles'] as Map?)?['full_name'] ?? 'Unknown Patient';
    final caregiverName =
        (response['users'] as Map?)?['name'] ?? 'Unknown Caregiver';
    final period   = response['period_label'] ?? '';
    final status   = response['status'] ?? 'SUBMITTED';
    final isReviewed = status == 'REVIEWED';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isReviewed
                ? MedicalTheme.accentGreen.withOpacity(0.08)
                : MedicalTheme.accentOrange.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isReviewed
                ? Icons.check_circle_outline_rounded
                : Icons.pending_outlined,
            color: isReviewed
                ? MedicalTheme.accentGreen
                : MedicalTheme.accentOrange,
          ),
        ),
        title: Text(
          patientName,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: MedicalTheme.darkSlate,
              fontSize: 14),
        ),
        subtitle: Text(
          '$period • by $caregiverName',
          style: const TextStyle(
              color: MedicalTheme.lightSlate, fontSize: 12),
        ),
        trailing: TextButton(
          onPressed: onView,
          child: const Text('View'),
        ),
      ),
    );
  }
}

class _ResponseDetailSheet extends StatelessWidget {
  final Map<String, dynamic> response;

  const _ResponseDetailSheet({required this.response});

  @override
  Widget build(BuildContext context) {
    final answers    = (response['answers'] as Map<String, dynamic>?) ?? {};
    final notes      = response['additional_notes'] as String? ?? '';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        padding: const EdgeInsets.all(20),
        child: ListView(
          controller: scrollCtrl,
          children: [
            const Text(
              'Questionnaire Answers',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: MedicalTheme.darkSlate),
            ),
            const SizedBox(height: 16),
            ...answers.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Q ${e.key.substring(0, 8)}…',
                          style: const TextStyle(
                              color: MedicalTheme.lightSlate, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AnswerChip(answer: e.value as String),
                    ],
                  ),
                )),
            if (notes.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Additional Notes',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.darkSlate),
              ),
              const SizedBox(height: 8),
              Text(notes,
                  style: const TextStyle(
                      color: MedicalTheme.lightSlate, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerChip extends StatelessWidget {
  final String answer;
  const _AnswerChip({required this.answer});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (answer) {
      case 'Yes':
        color = MedicalTheme.accentGreen;
        break;
      case 'No':
        color = MedicalTheme.accentCoral;
        break;
      default:
        color = MedicalTheme.accentOrange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(answer,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 3 – Assign Dementia Stage
// ─────────────────────────────────────────────────────────────

class _StagingTab extends ConsumerWidget {
  const _StagingTab();

  static const _stages = [
    'Non Demented',
    'Very Mild Demented',
    'Mild Demented',
    'Moderate Demented',
    'Severe Demented',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsesAsync = ref.watch(allResponsesAdminProvider);

    return responsesAsync.when(
      data: (responses) {
        // Show only SUBMITTED (not yet reviewed) responses
        final pending =
            responses.where((r) => r['status'] == 'SUBMITTED').toList();

        if (pending.isEmpty) {
          return const Center(
            child: Text(
              'No responses pending staging review.',
              style: TextStyle(color: MedicalTheme.lightSlate),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pending.length,
          itemBuilder: (_, i) => _StagingCard(
            response: pending[i],
            stages: _stages,
            onAssign: (stage, notes) =>
                _assignStage(context, ref, pending[i], stage, notes),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _assignStage(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> response,
    String stage,
    String notes,
  ) async {
    final client  = ref.read(supabaseClientProvider);
    final session = ref.read(authSessionProvider);

    try {
      // Insert stage record
      await client.from('patient_stages').insert({
        'patient_id':   response['patient_id'],
        'response_id':  response['id'],
        'assigned_by':  session?.user.id,
        'stage':        stage,
        'stage_notes':  notes,
      });

      // Mark response as REVIEWED
      await client
          .from('questionnaire_responses')
          .update({'status': 'REVIEWED'})
          .eq('id', response['id']);

      ref.invalidate(allResponsesAdminProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stage "$stage" assigned successfully.'),
            backgroundColor: MedicalTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning stage: $e'),
            backgroundColor: MedicalTheme.accentCoral,
          ),
        );
      }
    }
  }
}

class _StagingCard extends StatefulWidget {
  final Map<String, dynamic> response;
  final List<String> stages;
  final Future<void> Function(String stage, String notes) onAssign;

  const _StagingCard({
    required this.response,
    required this.stages,
    required this.onAssign,
  });

  @override
  State<_StagingCard> createState() => _StagingCardState();
}

class _StagingCardState extends State<_StagingCard> {
  String? _selectedStage;
  final _notesCtrl = TextEditingController();
  bool _isAssigning = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patientName =
        (widget.response['patient_profiles'] as Map?)?['full_name'] ??
            'Unknown Patient';
    final period = widget.response['period_label'] ?? '';
    final answers =
        (widget.response['answers'] as Map<String, dynamic>?) ?? {};

    // Score: "No" = 1 concern, "Sometimes" = 0.5
    final concernScore = answers.values.fold<double>(0, (sum, v) {
      if (v == 'No') return sum + 1;
      if (v == 'Sometimes') return sum + 0.5;
      return sum;
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person_outline_rounded,
                  color: MedicalTheme.primaryTeal),
              const SizedBox(width: 8),
              Text(
                patientName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.darkSlate,
                    fontSize: 16),
              ),
              const Spacer(),
              Text(period,
                  style: const TextStyle(
                      color: MedicalTheme.lightSlate, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            // Concern score indicator
            Row(children: [
              const Text('Concern Score: ',
                  style: TextStyle(
                      color: MedicalTheme.lightSlate, fontSize: 13)),
              Text(
                '${concernScore.toStringAsFixed(1)} / ${answers.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: concernScore > answers.length * 0.6
                      ? MedicalTheme.accentCoral
                      : concernScore > answers.length * 0.3
                          ? MedicalTheme.accentOrange
                          : MedicalTheme.accentGreen,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStage,
              decoration:
                  const InputDecoration(labelText: 'Assign Dementia Stage'),
              items: widget.stages
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedStage = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Staging Notes (Optional)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: (_selectedStage == null || _isAssigning)
                    ? null
                    : () async {
                        setState(() => _isAssigning = true);
                        await widget.onAssign(
                            _selectedStage!, _notesCtrl.text.trim());
                        if (mounted) setState(() => _isAssigning = false);
                      },
                child: _isAssigning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Assign Stage & Mark Reviewed'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
