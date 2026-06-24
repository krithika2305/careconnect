import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import 'package:go_router/go_router.dart';
import 'admin_users_tab.dart';
import 'admin_doctors_tab.dart';
import 'admin_caregivers_tab.dart';
import 'admin_patients_tab.dart';
import 'admin_logs_tab.dart';
import 'admin_verification_tab.dart';
import 'admin_dashboard_overview_tab.dart';
import 'admin_analytics_tab.dart';
import 'admin_notifications_tab.dart';
import 'admin_settings_tab.dart';

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
    _tabController = TabController(length: 11, vsync: this);
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
    if (mounted) context.go('/welcome');
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Users'),
            Tab(icon: Icon(Icons.medical_services_rounded), text: 'Doctors'),
            Tab(icon: Icon(Icons.favorite_rounded), text: 'Caregivers'),
            Tab(icon: Icon(Icons.person_rounded), text: 'Patients'),
            Tab(icon: Icon(Icons.verified_user_rounded), text: 'Verification'),
            Tab(icon: Icon(Icons.analytics_rounded), text: 'Analytics'),
            Tab(icon: Icon(Icons.help_outline_rounded), text: 'Questions'),
            Tab(icon: Icon(Icons.notifications_rounded), text: 'Notifications'),
            Tab(icon: Icon(Icons.article_outlined), text: 'Logs'),
            Tab(icon: Icon(Icons.settings_rounded), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AdminDashboardOverviewTab(tabController: _tabController),
          const AdminUsersTab(),
          const AdminDoctorsTab(),
          const AdminCaregiversTab(),
          const AdminPatientsTab(),
          const AdminVerificationTab(),
          const AdminAnalyticsTab(),
          const _QuestionsTab(),
          const AdminNotificationsTab(),
          const AdminLogsTab(),
          const AdminSettingsTab(),
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
              onSwitchChanged: (value) =>
                  _setActive(ref, questions[i], value),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _toggleActive(WidgetRef ref, Map<String, dynamic> q) async {
    final current = q['is_active'] as bool? ?? true;
    await _setActive(ref, q, !current);
  }

  Future<void> _setActive(
    WidgetRef ref,
    Map<String, dynamic> q,
    bool isActive,
  ) async {
    final client = ref.read(supabaseClientProvider);
    await client
        .from('questionnaire_questions')
        .update({'is_active': isActive})
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
  final ValueChanged<bool> onSwitchChanged;

  const _QuestionCard({
    required this.question,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onSwitchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = question['is_active'] as bool? ?? true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: MedicalTheme.primaryTeal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '#${question['sort_order']}',
              style: const TextStyle(
                color: MedicalTheme.primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          title: Text(
            question['question'] as String,
            style: TextStyle(
              color:
                  isActive ? MedicalTheme.darkSlate : MedicalTheme.lightSlate,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              decoration:
                  isActive ? null : TextDecoration.lineThrough,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            question['category'] as String? ?? 'General',
            style: const TextStyle(
              color: MedicalTheme.lightSlate,
              fontSize: 11,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isActive,
                  activeColor: MedicalTheme.primaryTeal,
                  onChanged: onSwitchChanged,
                ),
              ),
              PopupMenuButton<String>(
                iconSize: 18,
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'toggle') onToggle();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text(
                      'Edit',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      isActive ? 'Deactivate' : 'Activate',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: MedicalTheme.accentCoral,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
